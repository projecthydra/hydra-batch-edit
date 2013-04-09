module Hydra
  module BatchEdit
    class SearchService
      include Blacklight::Configurable
      include Blacklight::SolrHelper

      def initialize(session, user_key)
        @session = session
        @user_key = user_key
        self.class.copy_blacklight_config_from(::CatalogController)
      end

      solr_search_params_logic << :apply_gated_search

      def last_search_documents
        return [] if @session[:history].blank?
        last_search_id = @session[:history].first
        search = Search.find(last_search_id)
        _, document_list = get_search_results(search.query_params, :fl=>'id', :rows=>1000)
        document_list
      end

      # filter that sets up access-controlled lucene query in order to provide gated search behavior
      # @param solr_parameters the current solr parameters
      # @param user_parameters the current user-submitted parameters
      def apply_gated_search(solr_parameters, user_parameters)
        solr_parameters[:fq] ||= []

        # Grant access to public content
        user_access_filters = []
        user_access_filters << "#{solr_access_control_suffix('edit_access_group')}:public"

        # Grant access based on user id & role
        unless @user_key.blank?
          # for roles
          ::RoleMapper.roles(@user_key).each do |role|
            user_access_filters << "#{solr_access_control_suffix('edit_access_group')}:#{escape_slashes(role)}"
          end
          # for individual person access
          user_access_filters << "#{solr_access_control_suffix('edit_access_person')}:#{escape_slashes(@user_key)}"
        end
        solr_parameters[:fq] << user_access_filters.join(' OR ')
        solr_parameters
      end

      def escape_slashes(value)
        value.gsub('/', '\/')
      end

      def solr_access_control_suffix(key)
        "#{key}_ssim"
      end
    end
  end
end

