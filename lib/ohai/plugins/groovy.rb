#
# Author:: Doug MacEachern <dougm@vmware.com>
# Copyright:: Copyright (c) 2009 VMware, Inc.
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

Ohai.plugin(:Groovy) do
  provides "languages/groovy"

  depends "languages"

  collect_data do
    begin
      so = shell_out("groovy -v")
      if so.exitstatus == 0
        Ohai::Log.debug("Successfully ran groovy -v")
        groovy = Mash.new
        output = nil
        output = so.stdout.split
        if output.length >= 2
          groovy[:version] = output[2]
        end
        languages[:groovy] = groovy unless groovy.empty?
      end
    rescue Errno::ENOENT
      Ohai::Log.debug("Could not run groovy -v: Errno::ENOENT")
    end
  end
end
