# Author:: Christopher M Luciano (<cmlucian@us.ibm.com>)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Ohai.plugin(:Elixir) do
  provides "languages/elixir"

  depends "languages"

  collect_data do
    begin
      so = shell_out("elixir -v")
      if so.exitstatus == 0
        Ohai::Log.debug("Successfully ran elixir -v")
        elixir = Mash.new
        output = nil
        output = so.stdout.split
        elixir[:version] = output[1]
        languages[:elixir] = elixir unless elixir.empty?
      end
    rescue Errno::ENOENT
      Ohai::Log.debug("Could not run elixir -v: Errno::ENOENT")
    end
  end
end
