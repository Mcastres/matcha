require 'sinatra'
require 'rubygems'
require 'mysql2'
require 'htmlentities'
require 'erb'
require 'sinatra/flash'
require 'pony'
require 'digest'
require 'open-uri'
require 'uri'
require 'json'
require 'sinatra-websocket'
require 'nokogiri'
require 'net/http'
require 'sinatra/reloader' if development?

include ERB::Util
enable :sessions

set :server, 'thin'
set :sockets, []

class Matcha < Sinatra::Application

	@@client = Mysql2::Client.new(:host => "localhost", :username => "root", :password => "")
	@@client.query("CREATE DATABASE IF NOT EXISTS matcha")

	@@client = Mysql2::Client.new(:host => "localhost", :username => "root", :password => "", :database => "matcha", :encoding => 'utf8')

	def authenticate!
		if !session[:auth]
				redirect "users/sign_in"
		end
	end

	def redirect_flash(msg, type, path)
		flash[:type] = msg
		redirect path
	end

	def find_user_by_username(username)
		@@client.query("SELECT * FROM users WHERE username = '#{username}'").each(:as.to_s => :array)
	end

	def find_user_by_id(id)
		@@client.query("SELECT * FROM users WHERE id = '#{id}'").each(:as.to_s => :array)
	end

	def find_users
		@@client.query("SELECT * FROM users").each(:as.to_s => :array)
	end

	def location
		url = 'http://freegeoip.net/json/'
		uri = URI(url)
		response = Net::HTTP.get(uri)
		JSON.parse(response)
		tab = eval(response)
		lat = tab[:latitude]
		lon = tab[:longitude]
		return [lat,lon]
	end

	def zip_code(code)
		url = "https://maps.googleapis.com/maps/api/geocode/json?address=" + code.to_s + "&key=AIzaSyAMshR_QKYuVRzKZZvF1jS6TiJ4rv6kTt4"
		uri = URI(url)
		response = Net::HTTP.get(uri)
		data = JSON.parse(response)
		new_lat = data['results'][0]['geometry']['location']['lat']
		new_lng = data['results'][0]['geometry']['location']['lng']
		return [new_lat,new_lng]
	end

end

require_relative 'routes/init'
