require 'set'

module Pow
  class ZoneChange
    def initialize(server_id, zone, action, data)
      @server_id = server_id
      @zone = zone
      @action = action
      @data = data
    end

    def to_s
      "[#@server_id/#@zone] #@action zone: #@data"
    end

    def apply(client)
      client.server(@server_id).zone(@zone).send(@action, @data)
    end

    def self.create_zone(server_id, zone, data)
      new(server_id, zone, :create, data)
    end

    def self.change_zone(server_id, zone, data)
      new(server_id, zone, :change, data)
    end

    def self.modify_zone(server_id, zone, data)
      new(server_id, zone, :modify, data)
    end
  end

  class ZoneMetadataChange
    def initialize(server_id, zone, kind, action, data)
      @server_id = server_id
      @zone = zone
      @kind = kind
      @action = action
      @data = data
    end

    def to_s
      "[#@server_id/#@zone] #@action zone meta: #@data"
    end

    def apply(client)
      client.server(@server_id).zone(@zone).metadata(@kind).send(@action, *@data)
    end

    def self.change_metadata(server_id, zone, kind, values)
      new(server_id, zone, kind, :change, values)
    end

    def self.delete_metadata(server_id, zone, kind)
      new(server_id, zone, kind, :delete, [])
    end
  end

  class Planner
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def plan(desired)
      changeset = []

      desired.zones.each do |server_id, desired_zones|
        zones = client.server(server_id).zones.values

        desired_zones.each do |desired_zone|
          if zone = zones.find {|z| z.info[:name] == desired_zone.name }
            current_zone = zone.get

            changes = (desired_zone.members - %i[name rrsets metadata]).each_with_object({}) do |key, changes|
              if current_zone[key] != desired_zone[key]
                changes[key] = desired_zone[key]
              end
            end

            unless changes.empty?
              changeset << ZoneChange.change_zone(
                server_id, desired_zone.name, changes,
              )
            end

            rrsets = Hash.new {|h, k| h[k] = {} }
            current_zone[:rrsets].each do |rrset|
              rrsets[[rrset[:name], rrset[:type]]][:current] = rrset
            end
            desired_zone[:rrsets].each do |rrset|
              rrsets[[rrset.name, rrset.type]][:desired] = rrset
            end

            changes = rrsets.each.with_object([]) do |((name, type), rrset), changes|
              next if type == 'SOA'

              if !rrset[:desired]
                changes << {name: name, type: type, changetype: 'DELETE'}
              elsif !rrset[:current] || !compare_rrsets(rrset[:desired], rrset[:current])
                changes << rrset[:desired].to_h.merge(changetype: 'REPLACE')
              end
            end

            unless changes.empty?
              changeset << ZoneChange.modify_zone(
                server_id, desired_zone.name, changes,
              )
            end

            current_meta = zone.metadata
            desired_zone.metadata.each do |kind, desired_values|
              current_values = current_meta.fetch(kind, [])
              desired_values ||= []

              if desired_values.empty?
                if !current_values.empty?
                  changeset << ZoneMetadataChange.delete_metadata(server_id, desired_zone.name, kind)
                end
              elsif current_values.sort != desired_values.sort
                changeset << ZoneMetadataChange.change_metadata(server_id, desired_zone.name, kind, desired_values)
              end
            end
          else
            attrs = desired_zone.to_h
            attrs[:rrsets] = attrs[:rrsets].map(&:to_h)
            metadata = attrs.delete(:metadata)

            changeset << ZoneChange.create_zone(
              server_id, desired_zone.name, {nameservers: []}.merge(attrs),
            )

            unless metadata.empty?
              # todo
            end
          end
        end
      end

      changeset
    end

    private

    def compare_rrsets(r1, r2)
      raise ArgumentError, "names must match" if r1[:name] != r1[:name]
      raise ArgumentError, "types must match" if r1[:type] != r1[:type]

      r1[:ttl] == r2[:ttl] && Set.new(r1[:records]) == Set.new(r2[:records])
    end
  end
end
