require 'sinatra'
require 'sinatra/reloader'
require "sqlite3"


$db = SQLite3::Database.open "flowers.db"

$db.execute %{CREATE INDEX location
	        ON SIGHTINGS(LOCATION);

		CREATE INDEX name 
		ON SIGHTINGS(NAME);

		CREATE INDEX person
		ON SIGHTINGS(PERSON);

		CREATE INDEX sighted
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
		END;
		END;

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
		END;}



def recent_sightings_query flower_name
  sightings = $db.execute %{SELECT SIGHTED, PERSON, LOCATION,
			   FROM SIGHTINGS
			   WHERE NAME = "#{flower_name}" or NAME = (SELECT COMNAME FROM FLOWERS 				   WHERE GENUS || ' ' || SPECIES = "#{flower_name}")
			   ORDER BY SIGHTED DESC
			   LIMIT 10;}

  puts "#{flower_name} has not been sighted!" if sightings.empty?

  sightings
end

def get_flower_info_query flower_name
  flower_info = $db.execute %{SELECT * FROM FLOWERS WHERE GENUS || ' ' || SPECIES = "#{flower_name}" OR COMNAME = "#{flower_name}" }
  flower_info
end

get '/' do
  @flowers = []

  flowers_result = $db.execute "select * from flowers"

  flowers_result.each do |row|
    latin_name = row[0] + ' ' + row[1]
    common_name = row[2]

    @flowers.push( { :latin_name => latin_name, :common_name => common_name })
  end

  erb :index, :layout => :layout
end

get '/about' do
  "hello world!"
end

get '/flower/:flower_name' do
  @flower = get_flower_info_query params[:flower_name]
  @sightings = recent_sightings_query params[:flower_name]

  [@sightings, @flower].to_s
end

post '/signup' do
end

post '/login' do

end
