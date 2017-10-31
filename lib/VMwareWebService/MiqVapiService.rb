require 'vapi'
require 'com/vmware/cis'
require 'com/vmware/cis/tagging'
require 'VMwareWebService/miq_vapi/lookup_service_helper.rb'
require 'VMwareWebService/miq_vapi/sso'
require 'logger'

module MiqVapiService
  attr_reader :tag_svc, :category_svc, :tag_association_svc

  def vapi_service_initialize(ip, id, pwd, ssl_options = {})
    # VAPI endpoint was introduced in vSphere Management SDK 6.0
    if @apiVersion < '6.0'
      $vim_log.info("MiqVapiService: VC version < 6.0, not connecting to VAPI endpoint")
    else

      lookup_service_helper = LookupServiceHelper.new(ip, $vim_log)
      sso_url = lookup_service_helper.find_sso_url
      vapi_url = lookup_service_helper.find_vapi_urls.values.first
      ssl_options[:verify] = :none # TODO
      vapi_config = VAPI::Bindings::VapiConfig.new(vapi_url, ssl_options)
      sso = SSO::Connection.new(sso_url)
      sso.login(id, pwd)
      bearer_token = sso.request_bearer_token
      bearer_token_context = VAPI::Security.create_saml_bearer_security_context(bearer_token.to_s)
      vapi_config.set_security_context(bearer_token_context)
      vapi_session = Com::Vmware::Cis::Session.new(vapi_config)
      vapi_session_id = vapi_session.create
      vapi_config.set_security_context(VAPI::Security.create_session_security_context(vapi_session_id))

      @category_svc = Com::Vmware::Cis::Tagging::Category.new(vapi_config)
      @tag_svc = Com::Vmware::Cis::Tagging::Tag.new(vapi_config)
      @tag_association_svc = Com::Vmware::Cis::Tagging::TagAssociation.new(vapi_config)
    end
  rescue => err
    $vim_log.warn("MiqVapiService: Failed to connect to VAPI endpoint: #{err}")
  end

  def tagsByUid(_selspec = nil)
    tags = {}
    return tags if @tag_svc.nil?

    tag_ids = @tag_svc.list
    tag_ids.each do |t_id|
      tag = tag_svc.get(t_id)
      tags[t_id] = tag
      # TODO: do we need category detail?
      # category = category_svc.get(tag.category_id)
    end
    tags
  rescue => err
    $vim_log.warn("MiqVapiService: TagsByUid: #{err}")
  end

  def tagQueryAssociatedEntity(tag_ids)
    assoc_entities = {}
    return assoc_entities if @tag_association_svc.nil?

    begin
      tag_ids.each do |t_id|
        assoc_entities[t_id] = @tag_association_svc.list_attached_objects(t_id)
      end
    rescue => err
      $vim_log.warn("MiqVapiService: tagQueryAssociatedEntity: #{err}")
    end

    assoc_entities
  end
end
