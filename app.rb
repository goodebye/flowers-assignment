require 'sinatra'
require 'sinatra/reloader'
require "sqlite3"

db = SQLite3::Database.open "flowers.db"

users = {}

get '/' do
  (db.execute "select * from flowers").to_s
end

get '/about' do
  "hello world!"
end

post '/signup' do

end
