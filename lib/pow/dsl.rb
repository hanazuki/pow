module Pow
  module Dsl
    def self.define(path)
      GlobalContext.new(path) { instance_eval(File.read(path), path) }.result
    end

    class Error < StandardError
    end

    class ContextBase
      attr_reader :result

      def initialize(result, &block)
        @result = result
        instance_eval(&block) if block
      end
    end

    class GlobalContext < ContextBase
      Result = Struct.new(:zones, keyword_init: true)

      def initialize(path, &block)
        @path = path
        @server_id = 'localhost'

        super(
          Result.new(
            zones: {},
          ),
          &block
        )
      end

      private

      def server_id(value)
        @server_id = value
      end

      def server(value, &block)
        old_server_id = @server_id
        begin
          @server_id = value
          instance_eval(&block)
        ensure
          @server_id = old_server_id
        end
      end

      def zone(name, kind: 'Native', &block)
        unless name.end_with?(?.)
          raise Error, 'Zone name must be a FQDN with a trailing dot.'
        end
        (@result.zones[@server_id] ||= []) << ZoneContext.new(name, kind, &block).result
      end
      alias hosted_zone zone

      def master_zone(name, &block)
        zone(name, kind: 'Master', &block)
      end

      def slave_zone(name, &block)
        zone(name, kind: 'Slave', &block)
      end

      def require(path)
        file = File.expand_path(path, File.dirname(@path))
        if File.exist?(file)
          instance_eval(File.read(file), file)
        elsif File.exist?(file + '.rb')
          instance_eval(File.read(file + '.rb'), file + '.rb')
        else
          Kernel.require(path)
        end
      end
    end

    class ZoneContext < ContextBase
      Result = Struct.new(
        :name, :kind, :rrsets,
        :dnssec, :nsec3param, :nsec3narrow,
        :api_rectify, :soa_edit, :soa_edit_api,
        :metadata,
        keyword_init: true,
      )

      def initialize(name, kind, &block)
        super(
          Result.new(
            name: name,
            kind: kind,
            rrsets: [],
            dnssec: false,
            nsec3param: '',
            nsec3narrow: false,
            api_rectify: true,
            soa_edit: '',
            soa_edit_api: 'DEFAULT',
            metadata: {},
          ),
          &block
        )
      end

      private

      def dnssec(value)
        @result.dnssec = !!value
      end

      def nsec3param(value)
        @result.nsec3param = value.to_s
      end

      def nsec3narrow(value)
        @result.nsec3narrow = !!value
      end

      def api_rectify(value)
        @result.api_rectify = !!value
      end

      def soa_edit(value)
        @result.soa_edit = value.to_s
      end

      def soa_edit_api(value)
        @result.soa_edit_api = value.to_s
      end

      def rrset(name, type, &block)
        unless name == @result.name || name.end_with?(".#{@result.name}")
          raise Error, 'RRSet name must end with the zone name.'
        end
        @result.rrsets << RRSetContext.new(name, type.to_s, default_ttl: @default_ttl, &block).result
      end
      alias resource_record_set rrset

      def meta(kvpairs)
        kvpairs.each do |key, value|
          @result.metadata[key.to_s] = [*value].map(&:to_s)
        end
      end

      def default_ttl(ttl)
        @default_ttl = ttl.to_i
      end
    end

    class RRSetContext < ContextBase
      Result = Struct.new(:name, :type, :ttl, :records, keyword_init: true)

      def initialize(name, type, default_ttl:, &block)
        super(
          Result.new(
            name: name,
            type: type,
            records: [],
            ttl: default_ttl,
          ),
          &block
        )
      end

      private

      def ttl(ttl)
        @result.ttl = ttl
      end

      def records(*values)
        @result.records.concat(values.map {|v| {content: v, disabled: false} })
      end
      alias resource_records records
    end
  end
end
