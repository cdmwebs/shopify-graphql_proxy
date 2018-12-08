require "rack-proxy"

module Shopify
  class GraphQLProxy < Rack::Proxy
    PROXY_BASE_PATH = "/graphql"
    GRAPHQL_PATH = "/admin/api/graphql.json"
    VERSION = "0.2.0"

    def initialize(app = nil, opts= {})
      super
      @shop = opts[:shop] if opts[:shop]
      @password = opts[:password] if opts[:password]
      @session_key = opts.fetch(:session_key, :shopify)
    end

    def perform_request(env)
      @request = Rack::Request.new(env)

      path_info = @request.path_info
      request_method = @request.request_method

      if path_info =~ %r{^#{PROXY_BASE_PATH}} && request_method == "POST"
        shop = @shop ? @shop : value_from_shopify_session(:shop)
        token = @password ? @password : value_from_shopify_session(:token)

        unless shop && token
          return ["403", {"Content-Type" => "text/plain"}, ["Unauthorized"]]
        end

        backend = URI("https://#{shop}#{GRAPHQL_PATH}")

        env["HTTP_HOST"] = backend.host
        env["PATH_INFO"] = backend.path
        env["HTTP_X_SHOPIFY_ACCESS_TOKEN"] = token
        env["SCRIPT_NAME"] = ""
        env["HTTP_COOKIE"] = nil

        super(env)
      else
        @app.call(env)
      end
    end

    private
    def shopify_session
      @request.session.fetch(@session_key, {})
    end

    def value_from_shopify_session(key)
      shopify_session.fetch(key.to_s, nil)
    end
  end
end
