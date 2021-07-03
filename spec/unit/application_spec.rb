#
# Author:: Claire McQuin <claire@chef.io>
# Copyright:: Copyright (c) Chef Software Inc.
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

require "spec_helper"
require "ohai/application"

RSpec.describe "Ohai::Application" do

  let(:argv) { [] }
  let(:app) { Ohai::Application.new }

  before do
    @original_argv = ARGV
    ARGV.replace(argv)
  end

  after do
    ARGV.replace(@original_argv)
  end

  describe "#configure_ohai" do
    describe "loading configuration from a file" do
      let(:config_file) { "/local/workstation/config" }
      let(:config_loader) { instance_double("ChefConfig::WorkstationConfigLoader") }

      context "when specified on the command line" do
        let(:argv) { [ "-c", config_file ] }

        before do
          if windows?
            expect(ChefConfig::WorkstationConfigLoader).to receive(:new)
              .with(/[CD]:#{config_file}/, Ohai::Log)
              .and_return(config_loader)
          else
            expect(ChefConfig::WorkstationConfigLoader).to receive(:new)
              .with(config_file, Ohai::Log)
              .and_return(config_loader)
          end
        end

        it "loads the configuration file" do
          expect(config_loader).to receive(:load)
          app.configure_ohai
        end

        context "when the configuration file does not exist" do
          it "terminates the application" do
            expect(config_loader).to receive(:load).and_raise(ChefConfig::ConfigurationError)
            expect(Ohai::Application).to receive(:fatal!)
            app.configure_ohai
          end
        end
      end

      context "when a local workstation config exists" do
        before do
          expect(ChefConfig::WorkstationConfigLoader).to receive(:new)
            .with(nil, Ohai::Log)
            .and_return(config_loader)
        end

        it "loads the configuration file" do
          expect(config_loader).to receive(:load)
          app.configure_ohai
        end
      end
    end

    context "when CLI options are provided" do
      let(:argv) { [ "-d", directory ] }
      let(:directory) { "/some/fantastic/plugins" }

      it "does not generate deprecated config warnings for cli options" do
        expect(Ohai::Log).not_to receive(:warn)
          .with(/Ohai::Config\[:directory\] is deprecated/)
        app.configure_ohai
      end
    end

  end
end
