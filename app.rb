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
	        ON SIGHTINGS(LOCATION);}

$db.execute %{CREATE INDEX IF NOT EXISTS name
		ON SIGHTINGS(NAME);}

$db.execute %{CREATE INDEX IF NOT EXISTS person
		ON SIGHTINGS(PERSON);}

$db.execute %{CREATE INDEX IF NOT EXISTS sighted
		ON SIGHTINGS(SIGHTED);}		

$db.execute %{CREATE TRIGGER IF NOT EXISTS flower_update
		AFTER UPDATE OF COMNAME ON FLOWERS
		BEGIN
		UPDATE SIGHTINGS
		SET NAME = NEW.COMNAME
		WHERE NAME = OLD.COMNAME;
		END;}			

$db.execute %{CREATE TRIGGER IF NOT EXISTS flower_update
		AFTER UPDATE OF COMNAME ON FLOWERS
		BEGIN
		UPDATE SIGHTINGS
		SET NAME = NEW.COMNAME
		WHERE NAME = OLD.COMNAME;
		END;}

$db.execute %{CREATE TRIGGER IF NOT EXISTS no_location
		BEFORE INSERT ON SIGHTINGS
		WHEN ((SELECT FEATURES.LOCATION
		FROM FEATURES
		WHERE FEATURES.LOCATION = NEW.LOCATION) IS NULL) 
		BEGIN INSERT INTO FEATURES(LOCATION, CLASS)
		VALUES(NEW.LOCATION, 'UNKNOWN');
		END;}
		
$db.execute %{CREATE TRIGGER IF NOT EXISTS no_flower
		BEFORE INSERT ON SIGHTINGS
		BEGIN
		SELECT CASE
		WHEN ((SELECT COMNAME
		      FROM FLOWERS
		      WHERE COMNAME = NEW.NAME OR GENUS || ' ' || SPECIES = NEW.NAME) IS NULL) 
		      THEN RAISE (ABORT, 'Flower is not found')
		END; 
		END;}
		
$db.execute %{CREATE TRIGGER IF NOT EXISTS sci_name_change
		AFTER INSERT ON SIGHTINGS
		WHEN((SELECT GENUS || ' ' || SPECIES
				  FROM FLOWERS
				  WHERE GENUS = substr(NEW.NAME, 1, instr(NEW.NAME, ' ') - 1) 
				  AND SPECIES =substr(NEW.NAME, instr(NEW.NAME, ' ') + 1)) == NEW.NAME)
				  BEGIN	
				  UPDATE SIGHTINGS
				  SET NAME = (SELECT COMNAME
				              FROM FLOWERS
				              WHERE GENUS || ' ' || SPECIES = NEW.NAME)
				  WHERE NAME = NEW.NAME;
		END;}

$db.execute %{CREATE TRIGGER IF NOT EXISTS ud_no_flower
		BEFORE UPDATE ON FLOWERS
		BEGIN
		SELECT CASE
		WHEN((SELECT COMNAME
		      FROM FLOWERS
		      WHERE COMNAME = NEW.NAME) is NULL)
		      then
		      RAISE(ABORT, 'Flower is not found')
		      END;
		END;}
		
$db.execute %{CREATE TRIGGER IF NOT EXISTS ud_no_genus
		BEFORE UPDATE ON FLOWERS
		BEGIN
		SELECT CASE
		WHEN((SELECT GENUS
		      FROM FLOWERS
		      WHERE GENUS = NEW.GENUS) is NULL)
		      then
		      RAISE(ABORT, 'Genus is not found')
		      END;
		END;}
		
$db.execute %{CREATE TRIGGER IF NOT EXISTS ud_no_specices
		BEFORE UPDATE ON FLOWERS
		BEGIN
		SELECT CASE
		WHEN((SELECT SPECIES
		      FROM FLOWERS
		      WHERE SPECIES = NEW.SPECIES) is NULL)
		      then
		      RAISE(ABORT, 'Species is not found')
		      END;
		END;}
		
$db.execute %{CREATE TRIGGER IF NOT EXISTS no_flower_repeat
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

def person_sightings_query person_name
  person_name = ActiveRecord::Base.sanitize_sql(person_name)

  sightings = $db.execute %{SELECT * FROM SIGHTINGS WHERE PERSON = '#{person_name}'}

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

def insert_new_sighting(flower_name, person_name, location)
   $db.execute %{INSERT INTO SIGHTINGS(NAME, PERSON, LOCATION, SIGHTED)
                 VALUES('#{flower_name}', '#{person_name}', '#{location}', DateTime('now'));}
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

  location_info = $db.execute %{SELECT * FROM features WHERE location = "#{location_name}"}
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

get '/flower/:flower_url' do
  params[:flower_name] = params[:flower_url].gsub('_', ' ')
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

post '/flower/sighting' do
  protected!

  @flower_row = get_flower_info_query params[:flower_name]

  if (@flower_row.empty?)
    redirect '/notfound'
    return
  end

  @flower = flower_to_obj(@flower_row[0])

  insert_new_sighting(@flower[:common_name], current_user, params[:location])

  redirect %{/flower/#{@flower[:url]}}
end

get '/location/:location_name' do
  params[:location_name] = params[:location_name].gsub('_', ' ')
  loc_row = get_location_info_query params[:location_name].gsub('_', ' ')

  if (loc_row.empty?)
    redirect '/notfound'
    return
  end

  @location = location_to_obj(loc_row[0])

  @sightings = []
  (recent_sightings_location params[:location_name]).each do |row|
     @sightings.push location_sighting_to_obj(row)
   end

  erb :location, :layout => :layout
end

get '/notfound' do
  erb :notfound, :layout => :layout
end

get '/person/:person_name' do
  params[:person_name] = params[:person_name].gsub('_', ' ')

  @person = params[:person_name]

  sightings_rows = person_sightings_query params[:person_name]

  @sightings = []

  sightings_rows.each do |row| 
    @sightings.push(person_to_obj row)
  end

  erb :person, :layout => :layout
end

def flower_to_obj row
  latin_name = row[0] + ' ' + row[1]
  common_name = row[2]
  { :latin_name => latin_name, :common_name => common_name, :url => common_name.gsub(' ', '_') }
end

def sighting_to_obj row
  { :date => row[0],
    :person => row[1],
    :location => row[2],
    :location_url => row[2].gsub(' ', '_')
  }
end

def person_to_obj row
  { :name => row[0],
    :flower_url => row[0].gsub(' ', '_'),
    :person => row[1],
    :location => row[2],
    :location_url => row[2].gsub(' ', '_'),
    :date => row[3]
  }
end

def location_sighting_to_obj row
  { :name => row[0],
    :flower_url => row[0].gsub(' ','_'),
    :person => row[1],
    :date => row[2]
  }
end

def location_to_obj row
  if row[2].nil?
    row[2] = "Unknown latitude"
  end
  if row[3].nil?
    row[3] = "Unknown longitude"
  end
  if row[4].nil?
    row[4] = "Unknown map"
  end
  if row[5].nil?
    row[5] = "Unknown elevation"
  else
    row[5] = "#{row[5] } ft"
  end

  {
  location: row[0],
  feature_class:  row[1],
  latitude: row[2],
  longitude: row[3],
  map: row[4],
  elev: row[5]
  }
end
