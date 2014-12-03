require File.expand_path('../test_helper', __FILE__)

include Rack::Test::Methods

def app
  Tory::TaskServer
end

class HelpDummy
  include Tory::TaskHelpers
end

describe "Tory PXE Task Server" do
  
  before do
    @data = {
      mac_address: SecureRandom.hex(6),
      image: 'vostro230-64win7-mso13pro'
    }
    @task_path = File.expand_path('../../tmp/tasks', __FILE__)
  end
  
  it "should successfully return a greeting" do
    get '/' 
    last_response.body.must_equal( {message: 'Hello world'}.to_json)
  end
  
  describe 'loading system settings' do
    
    it 'knows own ip' do
      app.pxe_server.must_equal 'localhost'
    end
    
    it 'knows the storage server' do
      app.storage_server.must_equal 'localhost'
    end
  end
  
  describe 'handling input' do
    
    it 'responds gently to bad params' do
      post '/deploy', {foo: 'bar'}
      expected = {
        message: 'missing required parameters',
        errors: ['missing mac_address', 'missing image']
      }.to_json
      last_response.status.must_equal 422
      last_response.body.must_equal expected
    end
    
    it 'formats mac addresses with colons' do
      post '/deploy', {mac_address: "11:22:33:44:55:66", image: 'image' }
      File.exists?("#{@task_path}/01-11-22-33-44-55-66").must_equal true
    end
    
  end
  
  describe 'checking for existing tasks' do
    
    before do
      clean_tasks
      post '/deploy/', @data
    end
    
    it 'responds positively when a task exists' do
      get "/check/#{@data[:mac_address]}"
      last_response.body.must_equal({message: 'task active'}.to_json)
    end
    
    it 'responds negatively when no task exists' do
      get '/check/ff1122334455'
      last_response.status.must_equal 404
      expected = {
        message:'no task for that address',
        errors: ['ff1122334455']
      }.to_json
      last_response.body.must_equal(expected)
    end
    
    it 'responds with an error if no mac is given' do
      get '/check/'
      last_response.status.must_equal 404
      expected = {
        message: 'missing required parameters',
        errors: ['missing mac address']
      }.to_json
      last_response.body.must_equal expected
    end
    
  end
  
  describe 'deploying' do
    
    before do
      clean_tasks
    end
    
    it 'writes a deploy-job pxe file' do
      fmt = "01-" + @data[:mac_address].scan(/\w{2}/).join('-').upcase
      post '/deploy', @data
      File.exists?("#{@task_path}/#{fmt}").must_equal true
      job = File.read("#{@task_path}/#{fmt}")
      job.must_match(/#{@data[:mac_address]}/)
      job.must_match(/#{@data[:image]}/)
      job.must_match(/localhost/)
      job.must_match(/deploy/)
    end
    
    it 'writes an upload-job pxe file' do
      fmt = "01-" + @data[:mac_address].scan(/\w{2}/).join('-').upcase
      post '/upload', @data
      File.exists?("#{@task_path}/#{fmt}").must_equal true
      job = File.read("#{@task_path}/#{fmt}")
      job.must_match(/#{@data[:mac_address]}/)
      job.must_match(/#{@data[:image]}/)
      job.must_match(/localhost/)
      job.must_match(/upload/)
    end
    
  end
  
  describe 'Ending jobs' do
    it 'deletes the task if existing' do
      post '/deploy', @data
      fmt = "01-" + @data[:mac_address].scan(/\w{2}/).join('-').upcase
      delete "/finished/#{@data[:mac_address]}"
      File.exists?("#{@task_path}/#{fmt}").must_equal false
      
      expected = {
        message: 'task deleted'
      }.to_json
      
      last_response.body.must_equal expected
    end
    
    it 'gives error if no task' do
      mac = SecureRandom.hex(6)
      delete "/finished/#{mac}"
      
      expected = {
        message: 'no task file',
        errors: [mac]
      }.to_json
      last_response.status.must_equal 404
      last_response.body.must_equal expected
    end
  end
  
  private
  
  def clean_tasks
    system "rm -f #{@task_path}/*"
  end
  
end