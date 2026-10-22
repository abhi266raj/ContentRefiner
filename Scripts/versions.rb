#!/usr/bin/env ruby
# SPDX-License-Identifier: AGPL-3.0-only
require 'json'
components = {'ContentRefiner' => 'VERSION', 'ContentRefinerBase' => 'Packages/ContentRefinerBase/VERSION', 'ContentRefinerMac' => 'Packages/ContentRefinerMac/VERSION', 'ContentRefinerLinux' => 'Packages/ContentRefinerLinux/VERSION', 'ContentRefinerWindows' => 'Packages/ContentRefinerWindows/VERSION'}
base = ARGV.first
changed = []
components.each do |name, path|
  current = File.read(path).strip
  abort "Invalid version in #{path}" unless /\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z/.match?(current)
  previous = base && !base.empty? ? IO.popen(['git','show',"#{base}:#{path}"], err: File::NULL, &:read).strip : ''
  previous = '0.0.0' if previous.empty?
  comparison = current.split('.').map(&:to_i) <=> previous.split('.').map(&:to_i)
  abort "#{name} version decreased" if comparison.negative?
  changed << {'name'=>name,'version'=>current,'tag'=>(name == 'ContentRefiner' ? current : "#{name}-#{current}")} if comparison.positive?
end
puts JSON.generate(changed)
