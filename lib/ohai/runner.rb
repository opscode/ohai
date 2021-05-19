# frozen_string_literal: true
#
# Author:: Claire McQuin (<claire@chef.io>)
# Copyright:: Copyright (c) Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You may
# obtain a copy of the license at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either expressed or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License
#

require_relative "dsl"
require "benchmark" unless defined?(Benchmark)

module Ohai
  class Runner

    attr_reader :failed_plugins, :logger

    attr_accessor :transport_connection

    # safe_run: set to true if this runner will run plugins in
    # safe-mode. default false.
    def initialize(controller, safe_run = false)
      @provides_map = controller.provides_map
      @safe_run = safe_run
      @failed_plugins = []
      @logger = controller.logger.with_child
      @logger.metadata = { subsystem: "runner" }
    end

    # Runs plugins and any un-run dependencies.
    # If force is set to true, then this plugin and its dependencies
    # will be run even if they have been run before.
    #
    # @param [Ohai::DSL::Plugin] plugin
    #
    # @return void
    #
    def run_plugin(plugin)
      elapsed = Benchmark.realtime do
        unless plugin.is_a?(Ohai::DSL::Plugin)
          raise Ohai::Exceptions::InvalidPlugin, "Invalid plugin #{plugin} (must be an Ohai::DSL::Plugin or subclass)"
        end

        begin
          if plugin.version == :version7
            run_v7_plugin(plugin)
          else
            raise Ohai::Exceptions::InvalidPlugin, "Invalid plugin version #{plugin.version} for plugin #{plugin}"
          end
        rescue Ohai::Exceptions::Error, SystemExit # SystemExit: abort or exit from plug-in should exit Ohai with failure code
          raise
        rescue Exception => e
          logger.warn("Plugin #{plugin.name} threw exception #{e.inspect} #{e.backtrace.join("\n")}")
        end
      end
      logger.trace("Plugin #{plugin.name} took #{"%f" % elapsed.truncate(6)} seconds to run.")
    end

    # @param [Ohai::DSL::Plugin] plugin
    #
    # @return void
    #
    def run_v7_plugin(plugin)
      return true if plugin.optional? &&
        !Ohai.config[:run_all_plugins] &&
        !Ohai.config[:optional_plugins].include?(plugin.name)

      visited = [ plugin ]
      until visited.empty?
        next_plugin = visited.pop

        next if next_plugin.has_run?

        if visited.include?(next_plugin)
          raise Ohai::Exceptions::DependencyCycle, "Dependency cycle detected. Please refer to the following plugins: #{get_cycle(visited, plugin).join(", ")}"
        end

        dependency_providers = fetch_plugins(next_plugin.dependencies)

        # Remove the already ran plugins from dependencies if force is not set
        # Also remove the plugin that we are about to run from dependencies as well.
        dependency_providers.delete_if do |dep_plugin|
          dep_plugin.has_run? || dep_plugin.eql?(next_plugin)
        end

        if dependency_providers.empty?
          next_plugin.transport_connection = transport_connection
          @safe_run ? next_plugin.safe_run : next_plugin.run
          if next_plugin.failed
            @failed_plugins << next_plugin.name
          end
        else
          visited << next_plugin << dependency_providers.first
        end
      end
    end

    # @param [Array] attributes
    #
    # @return [Array]
    #
    def fetch_plugins(attributes)
      @provides_map.find_closest_providers_for(attributes)
    end

    # Given a list of plugins and the first plugin in the cycle,
    # returns the list of plugin source files responsible for the
    # cycle. Does not include plugins that aren't a part of the cycle
    def get_cycle(plugins, cycle_start)
      cycle = plugins.drop_while { |plugin| !plugin.eql?(cycle_start) }
      names = []
      cycle.each { |plugin| names << plugin.name }
      names
    end

  end
end
