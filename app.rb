require 'sinatra'
require 'sinatra/reloader'
require "sqlite3"


$db = SQLite3::Database.open "flowers.db"

def recent_sightings_query flower_name
  sightings = $db.execute "select * from sightings where name = \"#{flower_name}\""
  sightings
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
  @sightings = recent_sightings_query params[:flower_name]

  @sightings.to_s
end

post '/signup' do
end

post '/login' do

end
