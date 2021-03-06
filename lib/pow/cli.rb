require 'thor'
require 'pdns_api'

require_relative 'dsl'
require_relative 'plan'

module Pow
  class Cli < Thor
    map '-a' => :apply

    desc 'apply [ZONEFILE]', 'Apply zone changes'
    method_option :dry_run, type: :boolean, default: false, desc: 'No actions. Just print simulation'
    method_option :tls, type: :boolean, default: true, desc: 'Enable TLS'
    method_option :host, required: true
    method_option :port
    def apply(zonefile = 'Zonefile')
      client = PDNS::Client.new(
        scheme: options[:tls] ? 'https' : 'http',
        host: options[:host],
        port: options[:port],
        key: ENV.fetch('PDNS_API_KEY'),
      )

      changeset = Planner.new(client).plan(Dsl.define(zonefile))
      if changeset.empty?
        puts "No changes."
      else
        changeset.each do |c|
          puts c
          c.apply(client) unless options[:dry_run]
        end
      end
    end
  end
end
