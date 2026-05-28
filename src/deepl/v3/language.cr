require "json"

module DeepL
  class LanguageFeature
    include JSON::Serializable

    property name : String
    property needs_source_support : Bool?
    property needs_target_support : Bool?

    def initialize(@name, @needs_source_support = nil, @needs_target_support = nil)
    end
  end

  class LanguageResource
    include JSON::Serializable

    property name : String
    property features : Array(LanguageFeature)

    def initialize(@name, @features)
    end
  end

  class ResourceLanguage
    include JSON::Serializable

    property lang : String
    property name : String
    # ameba:disable Naming/QueryBoolMethods
    property usable_as_source : Bool
    # ameba:disable Naming/QueryBoolMethods
    property usable_as_target : Bool
    property status : String
    property features : Hash(String, JSON::Any)

    def initialize(
      @lang,
      @name,
      @usable_as_source,
      @usable_as_target,
      @status,
      @features,
    )
    end
  end

  class Translator
    # ameba:disable Naming/AccessorMethodName
    def get_language_resources : Array(LanguageResource)
      url = "#{base_server_url}/v3/languages/resources"
      response = Crest.get(url, headers: http_headers_base)
      handle_response(response)
      Array(LanguageResource).from_json(response.body)
    end

    def get_languages(resource : String, include_values : Array(String)? = nil) : Array(ResourceLanguage)
      url = "#{base_server_url}/v3/languages"
      params = HTTP::Params.build do |form|
        form.add("resource", resource)
        include_values.try &.each { |value| form.add("include", value) }
      end

      response = Crest.get(url, params: params, headers: http_headers_base)
      handle_response(response)
      Array(ResourceLanguage).from_json(response.body)
    end
  end
end
