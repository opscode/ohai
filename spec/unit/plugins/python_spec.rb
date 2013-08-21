#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Theodore Nordsieck (<theo@opscode.com>)
# Copyright:: Copyright (c) 2008-2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

describe Ohai::System, "plugin python" do

  before(:each) do
    @plugin = get_plugin("python")
    @plugin[:languages] = Mash.new
    @status = 0
    @stdout = "2.5.2 (r252:60911, Jan  4 2009, 17:40:26)\n[GCC 4.3.2]\n"
    @stderr = ""
    @plugin.stub(:run_command).with({:no_status_check=>true, :command=>"python -c \"import sys; print sys.version\""}).and_return([@status, @stdout, @stderr])
  end
  
  it "should get the python version from printing sys.version and sys.platform" do
    @plugin.should_receive(:run_command).with({:no_status_check=>true, :command=>"python -c \"import sys; print sys.version\""}).and_return([0, "2.5.2 (r252:60911, Jan  4 2009, 17:40:26)\n[GCC 4.3.2]\n", ""])
    @plugin.run
  end

  it "should set languages[:python][:version]" do
    @plugin.run
    @plugin.languages[:python][:version].should eql("2.5.2")
  end
  
  it "should not set the languages[:python] tree up if python command fails" do
    @status = 1
    @stdout = "2.5.2 (r252:60911, Jan  4 2009, 17:40:26)\n[GCC 4.3.2]\n"
    @stderr = ""
    @plugin.stub(:run_command).with({:no_status_check=>true, :command=>"python -c \"import sys; print sys.version\""}).and_return([@status, @stdout, @stderr])
    @plugin.run
    @plugin.languages.should_not have_key(:python)
  end

  ##########

  require File.expand_path(File.dirname(__FILE__) + '/../path/ohai_plugin_common.rb')

  expected = [{
                :env => [[], ["python"]],
                :platform => ["centos-5.9"],
                :arch => ["x86", "x64"],
                :ohai => { "languages" => { "python" => { "version" => "2.4.3" }}},
              },{
                :env => [[], ["python"]],
                :platform => ["centos-6.4"],
                :arch => ["x86", "x64"],
                :ohai => { "languages" => { "python" => { "version" => "2.6.6"}}},
              },{
                :env => [[], ["python"]],
                :platform => ["ubuntu-10.04"],
                :arch => ["x86", "x64"],
                :ohai => { "languages" => { "python" => { "version" => "2.6.5"}}},
              },{
                :env => [[], ["python"]],
                :platform => ["ubuntu-12.04"],
                :arch => ["x86", "x64"],
                :ohai => { "languages" => { "python" => { "version" => "2.7.3"}}},
              },{
                :env => [[], ["python"]],
                :platform => ["ubuntu-13.04"],
                :arch => ["x64"],
                :ohai => { "languages" => { "python" => { "version" => "2.7.4"}}},
              }]

  include_context "cross platform data"
  it_behaves_like "a plugin", ["languages", "python"], expected, ["python"]
end
