# Copyright 2014-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require 'savon'
require 'nokogiri'

# Utility class that helps use the lookup service.
class LookupServiceHelper

    attr_reader :wsdl_url, :soap_url, :logger
    attr_reader :serviceRegistration

    # Constructs a new instance.
    # @param ip [String] the server IP
    # @param logger [Logger] the logger
    def initialize(ip, logger)
        @logger = logger
        @soap_url = "https://#{ip}/lookupservice/sdk"
        @wsdl_url = "https://#{ip}/lookupservice/wsdl/lookup.wsdl"
    end

    # Connects to the lookup service.
    def connect
        rsc = RetrieveServiceContent.new(client).invoke()
        @serviceRegistration = rsc.get_service_registration()
        logger.info "service registration = #{serviceRegistration}"
    end

    # Finds the SSO service URL.
    # In a MxN setup where there are more than one PSC nodes;
    # This method returns the first SSO service endpoint URL
    # as returned by the lookup service.
    #
    # @return [String] SSO Service endpoint URL.
    def find_sso_url
        result = find_service_url(product='com.vmware.cis',
                                  service='cs.identity',
                                  endpoint='com.vmware.cis.cs.identity.sso',
                                  protocol='wsTrust')
        raise 'SSO URL not found' unless result && result.size > 0
        return result.values[0]
    end

    # Finds all the vAPI service endpoint URLs.
    # In a MxN setup where there are more than one management node;
    # this method returns more than one URL
    #
    # @return [Hash] vapi service endpoint URLs in a dictionary
    #     where the key is the node_id and the value is the service URL.
    def find_vapi_urls
        return find_service_url(product='com.vmware.cis',
                                service='cs.vapi',
                                endpoint='com.vmware.vapi.endpoint',
                                protocol='vapi.json.https.public')
    end

    # Finds the vapi service endpoint URL of a management node.
    #
    # @param node_id [String] The UUID of the management node.
    # @return [String] vapi service endpoint URL of a management node or
    #     nil if no vapi endpoint is found.
    def find_vapi_url(node_id)
        raise 'node_id is required' if node_id.nil?
        result = find_vapi_urls()
        raise 'VAPI URLs not found' unless result && result.size > 0
        return result[node_id]
    end

    # Finds all the vim service endpoint URLs
    # In a MxN setup where there are more than one management node;
    # this method returns more than one URL
    #
    # @return [Hash] vim service endpoint URLs in a dictionary where
    #     the key is the node_id and the value is the service URL.
    def find_vim_urls
        return find_service_url(product='com.vmware.cis',
                                service='vcenterserver',
                                endpoint='com.vmware.vim',
                                protocol='vmomi')
    end

    # Finds the vim service endpoint URL of a management node
    #
    # @param node_id [String] The UUID of the management node.
    # @return [String] vim service endpoint URL of a management node or
    #     nil if no vim endpoint is found.
    def find_vim_url(node_id)
        raise 'node_id is required' if node_id.nil?
        result = find_vim_urls()
        raise 'VIM URLs not found' unless result && result.size > 0
        return result[node_id]
    end

    # Finds all the spbm service endpoint URLs
    # In a MxN setup where there are more than one management node;
    # this method returns more than one URL
    #
    # @return [Hash] spbm service endpoint URLs in a dictionary where
    #     the key is the node_id and the value is the service URL.
    def find_vim_pbm_urls
        return find_service_url(product='com.vmware.vim.sms',
                                service='sms',
                                endpoint='com.vmware.vim.pbm',
                                protocol='https')
    end

    # Finds the spbm service endpoint URL of a management node
    #
    # @param node_id [String] The UUID of the management node.
    # @return [String] spbm service endpoint URL of a management node or
    #     nil if no spbm endpoint is found.
    def find_vim_pbm_url(node_id)
        raise 'node_id is required' if node_id.nil?
        result = find_vim_pbm_urls()
        raise 'PBM URLs not found' unless result && result.size > 0
        return result[node_id]
    end

    # Get the management node id from the instance name
    #
    # @param instance_name [String] The instance name of the management node
    # @return [String] The UUID of the management node or
    #     nil is no management node is found by the given instance name
    def get_mgmt_node_id(instance_name)
        raise 'instance_name is required' if instance_name.nil?
        result = find_mgmt_nodes()
        raise 'Management nodes not found' unless result && result.size > 0
        return result[instance_name]
    end

    def get_mgmt_node_instance_name(node_id)
        raise 'node_id is required' if node_id.nil?
        result = find_mgmt_nodes()
        raise 'Management nodes not found' unless result && result.size > 0
        result.each { |k, v| return k if v == node_id }
        nil
    end

    # Finds the instance name and UUID of the management node for M1xN1 or
    # when the PSC and management services all reside on a single node.
    def get_default_mgmt_node
        result = find_mgmt_nodes()
        raise 'Management nodes not found' unless result && result.size > 0
        #WHY: raise MultipleManagementNodeException.new if result.size > 1
        return [result.keys[0], result.values[0]]
    end

    # Finds all the management nodes
    #
    # @return [Hash] management node instance name and node id (UUID) in a dictionary.
    def find_mgmt_nodes
        #assert self.serviceRegistration is not None
        list = List.new(client, 'com.vmware.cis', 'vcenterserver',
                        'vmomi', 'com.vmware.vim')

        list.invoke()
        list.get_instance_names()
    end

    private

    # Finds a service URL with the given attributes.
    def find_service_url(product, service, endpoint, protocol)
        #assert serviceRegistration is not None
        list = List.new(client, product, service, protocol, endpoint)

        list.invoke()
        list.get_service_endpoints()
    end

    # Gets or creates the Savon client instance.
    def client
        @client ||= Savon.client do |globals|
            # see: http://savonrb.com/version2/globals.html
            globals.wsdl wsdl_url
            globals.endpoint soap_url

            globals.strip_namespaces false
            globals.env_namespace :S

            # set like this so https connection does not fail
            # TODO: find an acceptable solution for production
            globals.ssl_verify_mode :none

            # dev/debug settings
            globals.pretty_print_xml ENV['DEBUG_SOAP']
            globals.log ENV['DEBUG_SOAP']
        end
    end
end


# @abstract Base class for invocable service calls.
class Invocable

    attr_reader :operation, :client, :response

    # Constructs a new instance.
    # @param operation [Symbol] the operation name
    # @param client [Savon::Client] the client
    def initialize(operation, client)
        @operation = operation
        @client = client
    end

    # Invokes the service call represented by this type.
    def invoke
        request = request_xml.to_s
        @response = client.call(operation, xml:request)
        self # for chaining with new
    end

    # Builds the request XML content.
    def request_xml
        builder = Builder::XmlMarkup.new()
        builder.instruct!(:xml, encoding: "UTF-8")

        builder.tag!("S:Envelope",
                     "xmlns:S" => "http://schemas.xmlsoap.org/soap/envelope/") do |envelope|
            envelope.tag!("S:Body") do |body|
                body_xml(body)
            end
        end
        builder.target!
    end

    # Builds the body portion of the request XML content.
    # Specific service operations must override this method.
    def body_xml
        raise 'abstract method not implemented!'
    end

    # Gets the response XML content.
    def response_xml
        raise 'illegal state: response not set yet' if response.nil?
        @response_xml ||= Nokogiri::XML(response.to_xml)
    end

    def response_hash
        @response_hash ||= response.to_hash
    end
end

# Encapsulates the list operation of the lookup service.
class List < Invocable

    # Constructs a new instance.
    def initialize(client, product, service, protocol, endpoint)
        super(:list, client)

        @product = product
        @service = service
        @protocol = protocol
        @endpoint = endpoint
    end

=begin
    <S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
        <S:Body>
            <List xmlns="urn:lookup">
                <_this type="LookupServiceRegistration">ServiceRegistration</_this>
                <filterCriteria>
                    <serviceType>
                        <product>com.vmware.cis</product>
                        <type>cs.identity</type>
                    </serviceType>
                    <endpointType>
                        <protocol>wsTrust</protocol>
                        <type>com.vmware.cis.cs.identity.sso</type>
                    </endpointType>
                </filterCriteria>
            </List>
        </S:Body>
    </S:Envelope>
=end
    def body_xml(body)
        body.tag!("List", "xmlns" => "urn:lookup") do |list|
            #TODO: use the copy that was retrieved on startup?
            list.tag!("_this",
                      "type" => "LookupServiceRegistration") do |this|
                this << "ServiceRegistration"
            end
            list.tag!("filterCriteria") do |criteria|
                criteria.tag!("serviceType") do |stype|
                    stype.tag!("product") do |p|
                        p << @product
                    end
                    stype.tag!("type") do |t|
                        t << @service
                    end
                end
                criteria.tag!("endpointType") do |etype|
                    etype.tag!("protocol") do |p|
                        p << @protocol
                    end
                    etype.tag!("type") do |t|
                        t << @endpoint
                    end
                end
            end
        end
    end

    # Gets the service endpoint information from the response.
    # Support for MxN.
    # @return [Hash] a hash where the key is NodeId and the Value is a Service URL
    def get_service_endpoints
        result = {}
=begin
    <ListResponse xmlns="urn:lookup">
        <returnval>
            <serviceVersion>2.0</serviceVersion>
            <vendorNameResourceKey/>
            <vendorNameDefault/>
            <vendorProductInfoResourceKey/>
            <vendorProductInfoDefault/>
            <serviceEndpoints>
                <url>https://pa-rdinfra3-vm7-dhcp5583.eng.vmware.com/sts/STSService/vsphere.local</url>
                <endpointType>
                    <protocol>wsTrust</protocol>
                    <type>com.vmware.cis.cs.identity.sso</type>
                </endpointType>
                <sslTrust>
                    ...
                </sslTrust>
            </serviceEndpoints>
            <serviceNameResourceKey/>
            <serviceNameDefault/>
            <serviceDescriptionResourceKey/>
            <serviceDescriptionDefault/>
            <ownerId>pa-rdinfra3-vm7-dhcp5583.eng.vmware.com@vsphere.local</ownerId>
            <serviceType>
                <product>com.vmware.cis</product>
                <type>cs.identity</type>
            </serviceType>
            <nodeId/>
            <serviceId>6a8a5058-5d3d-4d42-bb5e-383b91c8732e</serviceId>
            <siteId>default-first-site</siteId>
        </returnval>
    </ListResponse>
=end
        return_val = response_hash[:list_response][:returnval]
        return_val = [return_val] if return_val.is_a? Hash
        return_val.each { |entry|
            #FYI: the node_id is sometimes null, so use the service_id in this case
            node_id = entry[:node_id] || entry[:service_id]
            result[node_id] = entry[:service_endpoints][:url]
        }
        return result
    end

    def get_instance_names
        result = {}
=begin
        <serviceAttributes>
            <key>com.vmware.cis.cm.GroupInternalId</key>
            <value>com.vmware.vim.vcenter</value>
        </serviceAttributes>
        <serviceAttributes>
            <key>com.vmware.cis.cm.ControlScript</key>
            <value>vmware-vpxd.sh</value>
        </serviceAttributes>
        <serviceAttributes>
            <key>com.vmware.cis.cm.HostId</key>
            <value>906477a1-24c6-4d48-9e99-55ef962878f7</value>
        </serviceAttributes>
        <serviceAttributes>
            <key>com.vmware.vim.vcenter.instanceName</key>
            <value>pa-rdinfra3-vm7-dhcp5583.eng.vmware.com</value>
        </serviceAttributes>
=end
        return_val = response_hash[:list_response][:returnval]
        return_val = [return_val] if return_val.is_a? Hash
        return_val.each { |entry|
            node_id = entry[:node_id]
            #TODO: is it possible there be 0 or 1 attrs?  if so, deal with it.
            attrs = entry[:service_attributes]
            attrs.each { |attr|
                if attr[:key] == 'com.vmware.vim.vcenter.instanceName'
                    result[attr[:value]] = node_id
                end
            }
        }
        return result
    end
end

# Encapsulates the RetrieveServiceContent operation of the lookup service.
class RetrieveServiceContent < Invocable

    # Constructs a new instance.
    def initialize(client)
        super(:retrieve_service_content, client)
    end

=begin
    <S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
        <S:Body>
            <RetrieveServiceContent xmlns="urn:lookup">
                <_this type="LookupServiceInstance">ServiceInstance</_this>
            </RetrieveServiceContent>
        </S:Body>
    </S:Envelope>
=end
    def body_xml(body)
        body.tag!("RetrieveServiceContent", "xmlns" => "urn:lookup") do |rsc|
            rsc.tag!("_this", "type" => "LookupServiceInstance") do |this|
                this << "ServiceInstance"
            end
        end
    end

=begin
    ...
        <RetrieveServiceContentResponse xmlns="urn:lookup">
            <returnval>
                <lookupService type="LookupLookupService">lookupService</lookupService>
                <serviceRegistration type="LookupServiceRegistration">ServiceRegistration</serviceRegistration>
                <deploymentInformationService type="LookupDeploymentInformationService">deploymentInformationService</deploymentInformationService>
                <l10n type="LookupL10n">l10n</l10n>
            </returnval>
        </RetrieveServiceContentResponse>
    ...
=end
    def get_service_registration
        return_val = response_hash[:retrieve_service_content_response][:returnval]
        result = return_val[:service_registration]
        result
    end
end

class MultipleManagementNodeException < Exception
end

# main: quick self tester
if __FILE__ == $0
    require 'logger'
    logger = Logger.new(STDOUT)
    ip = ARGV[0]
    ls_helper = LookupServiceHelper.new(ip, logger)
    ls_helper.connect()
    logger.info '***************************************'
    logger.info  "SSO URL: #{ls_helper.find_sso_url()}"
    logger.info  "VAPI URL: #{ls_helper.find_vapi_urls()}"
    logger.info  "VIM URL: #{ls_helper.find_vim_urls()}"
    logger.info  "PBM URL: #{ls_helper.find_vim_pbm_urls()}"
    logger.info  "Mgmt Nodes: #{ls_helper.find_mgmt_nodes()}"
end
