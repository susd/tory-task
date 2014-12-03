require 'sinatra'
require 'sinatra/config_file'
require 'json'
require File.expand_path('helpers', File.dirname(__FILE__))

configure do
  set :server, :puma
end

module Tory
  class TaskServer < Sinatra::Base
    register Sinatra::ConfigFile
    
    config_file 'config/settings.yml'
    
    before do
      content_type :json
    end
    
    get '/' do
      json_response(200, 'Hello world')
    end
    
    get '/check/?' do
      json_response(404, 'missing required parameters', ['missing mac address'])
    end
    
    get '/check/:mac' do
      @mac = params[:mac] || params[:mac_address]
      unless @mac.nil?
        affirm_task(normalize_mac(@mac))
      end
    end
    
    post '/deploy/?' do
      parse_params
      unless @mac.nil?
        deploy
        affirm_task(@mac)
      end
    end
    
    post '/upload/?' do
      parse_params
      unless @mac.nil?
        upload
        affirm_task(@mac)
      end
    end
    
    delete '/finished/:mac' do
      @mac = params[:mac] || params[:mac_address]
      task_file = "#{settings.task_path}/#{pxe_mac(@mac)}"
      if File.exists? task_file
        File.delete task_file
        json_response(200, 'task deleted')
      else
        json_response(404, 'no task file', [@mac])
      end
    end
    
    helpers do
      include Tory::TaskHelpers
    end
    
  end
end