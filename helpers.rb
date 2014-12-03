module Tory
  module TaskHelpers
    
    def parse_params
      @mac = params[:mac] || params[:mac_address]
      @image = params[:image]
      @pxe = settings.pxe_server
      @storage = settings.storage_server
      @app = settings.app_server
      
      if @mac.nil? || @image.nil?
        errors = []
        errors << 'missing mac_address' if @mac.nil?
        errors << 'missing image' if @image.nil?
        json_response(422, 'missing required parameters', errors)
      end
    end
    
    def pxe_mac(mac)
      flat = normalize_mac(mac)
      "01-" << flat.scan(/\w{2}/).join('-').downcase
    end
    
    def normalize_mac(mac)
      if mac.size > 17
        mac = mac[2..-1]
      end
      
      mac.downcase.gsub(/\:|\-/, '')
    end
    
    def write_pxe_file(data)
      File.open("#{settings.task_path}/#{pxe_mac(@mac)}", 'w') do |f|
        f << data
      end
    end
    
    def affirm_task(mac)
      if File.exists? "#{settings.task_path}/#{pxe_mac(mac)}"
        json_response(200, 'task active')
      else
        errors = [mac]
        json_response(404, 'no task for that address', errors)
      end
    end
    
    def deploy
      data = erb :deploy
      write_pxe_file(data)
    end
    
    def upload
      data = erb :upload
      write_pxe_file(data)
    end
    
    def json_response(status_code, message, errors = [])
      status status_code
      resp = {message: message}
      if errors.any?
        resp[:errors] = errors
      end
      body resp.to_json
    end
    
  end
end