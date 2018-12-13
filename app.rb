require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'image_searcher'
require 'active_record'

$users = { "admin" => "admin"}

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and $users.has_key?(@auth.credentials[0]) and $users[@auth.credentials[0]] == @auth.credentials[1]
  end

  def current_user
    if authorized?
      return @auth.credentials[0]
    end
    ""
  end
end

before "*" do
  puts current_user, "fuck off"
  @user = current_user
end

post '/signup' do
  if authorized?
    redirect '/'
  else
    if !$users.has_key? params[:username]
      $users[params[:username]] = params[:password]

      redirect '/signup_redirect'
    end
  end
end

get '/signup_redirect' do
  protected!

  redirect '/'
end

get '/protected' do
  protected!
  "Welcome, authenticated client"
end

get '/signup' do
  erb :signup, :layout => :layout
end

$db = SQLite3::Database.open "flowers.db"

# Triggers and index
$db.execute %{CREATE INDEX IF NOT EXISTS location
	        ON SIGHTINGS(LOCATION);

		CREATE INDEX IF NOT EXISTS name
		ON SIGHTINGS(NAME);

		CREATE INDEX IF NOT EXISTS person
		ON SIGHTINGS(PERSON);

		CREATE INDEX IF NOT EXISTS sighted
		ON SIGHTINGS(SIGHTED);

		CREATE TRIGGER flower_update
		AFTER UPDATE OF COMNAME ON FLOWERS
		BEGIN
		UPDATE SIGHTINGS
		SET NAME = NEW.COMNAME
		WHERE NAME = OLD.COMNAME;
		END;

		CREATE TRIGGER no_location
		BEFORE INSERT ON SIGHTINGS
		WHEN ((SELECT FEATURES.LOCATION
		FROM FEATURES
		WHERE FEATURES.LOCATION = NEW.LOCATION) IS NULL) 
		BEGIN INSERT INTO FEATURES(LOCATION, CLASS)
		VALUES(NEW.LOCATION, 'UNKNOWN');
		END;

		CREATE TRIGGER no_flower
		BEFORE INSERT ON SIGHTINGS
		BEGIN
		SELECT CASE
		WHEN ((SELECT COMNAME
		      FROM FLOWERS
		      WHERE COMNAME = NEW.NAME OR GENUS || ' ' || SPECIES = NEW.NAME) IS NULL) 
		      THEN RAISE (ABORT, 'Flower is not found')
		END; END;

		CREATE TRIGGER sci_name_change
		AFTER INSERT ON SIGHTINGS
		WHEN((SELECT GENUS || ' ' || SPECIES
				  FROM FLOWERS
				  WHERE GENUS =  substr(NEW.NAME, 1, instr(NEW.NAME, ' ') - 1) 
				  AND SPECIES = substr(NEW.NAME, instr(NEW.NAME, ' ') + 1)) == NEW.NAME)
				  BEGIN	
				  UPDATE SIGHTINGS
				  SET NAME = (SELECT COMNAME
				              FROM FLOWERS
				              WHERE GENUS || ' ' || SPECIES = NEW.NAME)
				  WHERE NAME = NEW.NAME;
		END;

		CREATE TRIGGER ud_no_flower
		BEFORE UPDATE ON FLOWERS
		BEGIN
		SELECT CASE
		WHEN((SELECT COMNAME
		      FROM FLOWERS
		      WHERE COMNAME = NEW.NAME) is NULL)
		      then
		      RAISE(ABORT, 'Flower is not found')
		      END;
		END;

		CREATE TRIGGER ud_no_genus
		BEFORE UPDATE ON FLOWERS
		BEGIN
		SELECT CASE
		WHEN((SELECT GENUS
		      FROM FLOWERS
		      WHERE GENUS = NEW.GENUS) is NULL)
		      then
		      RAISE(ABORT, 'Genus is not found')
		      END;
		END;

		CREATE TRIGGER ud_no_specices
		BEFORE UPDATE ON FLOWERS
		BEGIN
		SELECT CASE
		WHEN((SELECT SPECIES
		      FROM FLOWERS
		      WHERE SPECIES = NEW.SPECIES) is NULL)
		      then
		      RAISE(ABORT, 'Species is not found')
		      END;
		END;

		CREATE TRIGGER no_flower_repeat
		BEFORE INSERT ON FLOWERS
		BEGIN 
		SELECT CASE
		WHEN((select GENUS 
		      FROM FLOWERS
		      WHERE GENUS LIKE NEW.GENUS) LIKE NEW.GENUS
		     AND
		     (SELECT SPECIES
		      FROM FLOWERS
		      WHERE SPECIES LIKE NEW.SPECIES) LIKE NEW.SPECIES
		     OR
		     (SELECT COMNAME
		      FROM FLOWERS
		      WHERE COMNAME LIKE NEW.COMNAME) LIKE NEW.COMNAME)
		     THEN 
		     RAISE(ABORT, 'Flower already exists!')
		 END;
		END;}


def recent_sightings_query flower_name
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)

  sightings = $db.execute %{SELECT SIGHTED, PERSON, LOCATION
			   FROM SIGHTINGS
			   WHERE NAME = '#{flower_name}' or NAME = (SELECT COMNAME FROM FLOWERS 				   WHERE GENUS || ' ' || SPECIES = "#{flower_name}")
			   ORDER BY SIGHTED DESC
			   LIMIT 10;}

  sightings
end

def recent_sightings_location location_name
  location_name = ActiveRecord::Base.sanitize_sql(location_name)

  sightings = $db.execute %{SELECT NAME, PERSON, SIGHTED
				FROM SIGHTINGS
				WHERE LOCATION = '#{location_name}'
				ORDER BY SIGHTED DESC
				LIMIT 10;}
  sightings
end

def recent_sightings_name person
  person = ActiveRecord::Base.sanitize_sql(person)

  sightings = $db.execute %{SELECT NAME, LOCATION, SIGHTED
				FROM SIGHTINGS
				WHERE PERSON = '#{person}'
				ORDER BY SIGHTED DESC
				LIMIT 10;}
  sightings
end

# These methods assume the user cannot enter a blank input
# Not sure if that needs to be caught here or elsewhere
def update_flower_name(flower_name, new_name)
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)
  new_name = ActiveRecord::Base.sanitize_sql(new_name)

  $db.execute %{UPDATE FLOWERS
		SET COMNAME = '#{new_name}'
		WHERE COMNAME = '#{flower_name}'}
end


def update_flower_genus(flower_name, genus_name)
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)
  genus_name = ActiveRecord::Base.sanitize_sql(genus_name)

 $db.execute %{UPDATE FLOWERS
		SET GENUS = '#{new_name}'
		WHERE COMNAME = '#{flower_name}'}
end

def update_flower_species(flower_name, species_name)
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)
  species_name = ActiveRecord::Base.sanitize_sql(genus_name)

  $db.execute %{UPDATE FLOWERS
		SET SPECIES = '#{species_name}'
		WHERE COMNAME = '#{flower_name}'}
end

def insert_new_sighting(flower_name, person_name, location, date)

   $db.execute %{INSERT INTO SIGHTINGS(NAME, PERSON, LOCATION, SIGHTED)
                 VALUES('#{flower_name}', '#{person_name}', '#{location}', '#{date}');}
end

def insert_new_flower(comname, genus, species)

   $db.execute %{INSERT INTO FLOWERS(GENUS, SPECIES, COMNAME)
                 VALUES('#{genus}', '#{species}','#{comname}');}
end

def get_flower_info_query flower_name
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)

  flower_info = $db.execute %{SELECT * FROM FLOWERS WHERE GENUS || ' ' || SPECIES = "#{flower_name}" OR COMNAME = "#{flower_name}"}
  flower_info
end

def get_location_info_query location_name
  location_name = ActiveRecord::Base.sanitize_sql(location_name)

  location_info = $db.execute %{SELECT * FROM locations WHERE name = "#{location_name}"}
  location_info
end

get '/' do
  @flowers = []

  flowers_result = $db.execute "select * from flowers"

  flowers_result.each do |row|
    @flowers.push(flower_to_obj(row))
  end

  @title = "Welcome!"

  erb :index, :layout => :layout
end

get '/about' do
  "hello world!"
end

get '/flower/:flower_name' do
  @flower_row = get_flower_info_query params[:flower_name]

  if (@flower_row.empty?)
    redirect '/notfound'
    return
  end

  @flower = flower_to_obj(@flower_row[0])
  @flower[:image_url] = ImageSearcher::Client.new.search(query: params[:flower_name])[0]["tbUrl"]

  tmpsightings = recent_sightings_query params[:flower_name]

  @sightings = []

  tmpsightings.each do |row|
    @sightings.push sighting_to_obj(row)
  end

  @title = @flower[:common_name]

  erb :flower, :layout => :layout
end

get '/location/:location_name' do
  @location = get_location_info_query params[:location_name]

  @location
end

get '/notfound' do
  erb :notfound, :layout => :layout
end

def flower_to_obj row
  latin_name = row[0] + ' ' + row[1]
  common_name = row[2]
  { :latin_name => latin_name, :common_name => common_name }
end

def sighting_to_obj row
  { :date => row[0],
    :person => row[1],
    :location => row[2]}
end
