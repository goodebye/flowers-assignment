require 'sinatra'
require 'sinatra/reloader'
require "sqlite3"

db = SQLite3::Database.open "flowers.db"

users = {}

get '/' do
  @flowers = (db.execute "select * from flowers").to_s
  erb :'index', :layout => :'layout'
end

get '/about' do
  "hello world!"
end

post '/signup' do
end

post '/login' do

end
