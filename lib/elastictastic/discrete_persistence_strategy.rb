require 'singleton'

module Elastictastic
  class DiscretePersistenceStrategy
    include Singleton

    attr_accessor :auto_refresh

    def create(doc)
      response = Elastictastic.client.create(
        doc.index,
        doc.class.type,
        doc.id,
        doc.elasticsearch_doc,
        params_for(doc)
      )
      doc.id = response['_id']
      doc.version = response['_version']
      doc.persisted!
    end

    def update(doc)
      response = Elastictastic.client.update(
        doc.index,
        doc.class.type,
        doc.id,
        doc.elasticsearch_doc,
        params_for(doc)
      )
      doc.version = response['_version']
      doc.persisted!
    end

    def destroy(doc)
      response = Elastictastic.client.delete(
        doc.index.name,
        doc.class.type,
        doc.id,
        params_for(doc)
      )
      doc.transient!
      response['found']
    end

    private

    def params_for(doc)
      {}.tap do |params|
        params[:refresh] = true if Elastictastic.config.auto_refresh
        params[:parent] = doc._parent_id if doc._parent_id
        params[:version] = doc.version if doc.version
      end
    end
  end
end
