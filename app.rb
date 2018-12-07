require 'sinatra'
require 'sinatra/reloader'
require "sqlite3"


$db = SQLite3::Database.open "flowers.db"

def recent_sightings_query flower_name
  sightings = $db.execute %{SELECT SIGHTED, PERSON, LOCATION, NAME
			   FROM SIGHTINGS
			   WHERE NAME = "#{flower_name}" or NAME = (select comname from flowers 				   WHERE genus || ' ' || species = "#{flower_name}")
			   ORDER BY SIGHTED DESC
			   LIMIT 10;}

  puts "#{flower_name} has not been sighted!" if sightings.empty?

  sightings
end

def get_flower_info_query flower_name
  flower_info = $db.execute %{select * from flowers  WHERE genus || ' ' || species = "#{flower_name}" OR COMNAME = "#{flower_name}" }
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
