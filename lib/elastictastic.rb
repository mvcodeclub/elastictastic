require 'active_support/core_ext'
require 'active_model'
require 'elastictastic/errors'

module Elastictastic
  autoload :Association, 'elastictastic/association'
  autoload :BulkPersistenceStrategy, 'elastictastic/bulk_persistence_strategy'
  autoload :Callbacks, 'elastictastic/callbacks'
  autoload :ChildCollectionProxy, 'elastictastic/child_collection_proxy'
  autoload :Client, 'elastictastic/client'
  autoload :Configuration, 'elastictastic/configuration'
  autoload :Dirty, 'elastictastic/dirty'
  autoload :DiscretePersistenceStrategy, 'elastictastic/discrete_persistence_strategy'
  autoload :Document, 'elastictastic/document'
  autoload :Field, 'elastictastic/field'
  autoload :Index, 'elastictastic/index'
  autoload :MassAssignmentSecurity, 'elastictastic/mass_assignment_security'
  autoload :Middleware, 'elastictastic/middleware'
  autoload :NestedCollectionProxy, 'elastictastic/nested_collection_proxy'
  autoload :NestedDocument, 'elastictastic/nested_document'
  autoload :Observer, 'elastictastic/observer'
  autoload :Observing, 'elastictastic/observing'
  autoload :OptimisticLocking, 'elastictastic/optimistic_locking'
  autoload :ParentChild, 'elastictastic/parent_child'
  autoload :Persistence, 'elastictastic/persistence'
  autoload :Properties, 'elastictastic/properties'
  autoload :Resource, 'elastictastic/resource'
  autoload :Scope, 'elastictastic/scope'
  autoload :ScopeBuilder, 'elastictastic/scope_builder'
  autoload :Scoped, 'elastictastic/scoped'
  autoload :Search, 'elastictastic/search'
  autoload :ServerError, 'elastictastic/server_error'
  autoload :TestHelpers, 'elastictastic/test_helpers'
  autoload :Util, 'elastictastic/util'
  autoload :Validations, 'elastictastic/validations'

  class <<self
    attr_writer :config

    def config
      @config ||= Configuration.new
    end

    def client
      Thread.current['Elastictastic::client'] ||= Client.new(config)
    end

    def persister=(persister)
      Thread.current['Elastictastic::persister'] = persister
    end

    def persister
      Thread.current['Elastictastic::persister'] ||=
        Elastictastic::DiscretePersistenceStrategy.instance
    end

    def bulk
      original_persister = self.persister
      begin
        self.persister = Elastictastic::BulkPersistenceStrategy.new
        yield
        self.persister.flush
      rescue Elastictastic::CancelBulkOperation
        # Nothing to see here...
      ensure
        self.persister = original_persister
      end
    end

    def Index(name_or_index)
      Index === name_or_index ?  name_or_index : Index.new(name_or_index)
    end

    private

    def new_transport
      transport_class = const_get("#{config.transport.camelize}Transport")
      transport_class.new(config)
    end
  end
end

require 'elastictastic/railtie' if defined? Rails
