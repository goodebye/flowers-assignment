require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'image_searcher'
require 'active_record'

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
		BEGIN
		SELECT CASE
		WHEN ((SELECT FEATURES.LOCATION
		      FROM FEATURES
		      WHERE FEATURES.LOCATION = NEW.LOCATION) IS NULL) 
		      THEN RAISE (ABORT, 'Location is not found')
		END;
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

# These methods assume the user cannot enter a blank input
# Not sure if that needs to be caught here or elsewhere
def update_flower_name(flower_name, new_name)
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)
  new_name = ActiveRecord::Base.sanitize_sql(new_name)

  $db.execute %{UPDATE FLOWERS
		SET COMNAME = #{new_name}
		WHERE COMNAME = #{flower_name}}
end


def update_flower_genus(flower_name, genus_name)
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)
  genus_name = ActiveRecord::Base.sanitize_sql(genus_name)

 $db.execute %{UPDATE FLOWERS
		SET GENUS = #{new_name}
		WHERE COMNAME = #{flower_name}}
end

def update_flower_species(flower_name, species_name)
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)
  species_name = ActiveRecord::Base.sanitize_sql(genus_name)

  $db.execute %{UPDATE FLOWERS
		SET SPECIES = #{species_name}
		WHERE COMNAME = #{flower_name}}
end

def get_flower_info_query flower_name
  flower_name = ActiveRecord::Base.sanitize_sql(flower_name)

  flower_info = $db.execute %{SELECT * FROM FLOWERS WHERE GENUS || ' ' || SPECIES = "#{flower_name}" OR COMNAME = "#{flower_name}" }
  flower_info
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

  @sightings = recent_sightings_query params[:flower_name]
  @title = @flower[:common_name]

  erb :flower, :layout => :layout
end

post '/signup' do
end

post '/login' do

end

get '/notfound' do
  erb :notfound, :layout => :layout
end

def flower_to_obj row
  puts "hey", row.size
  latin_name = row[0] + ' ' + row[1]
  common_name = row[2]
  { :latin_name => latin_name, :common_name => common_name }
end
