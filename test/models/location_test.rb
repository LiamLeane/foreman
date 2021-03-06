require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  setup do
    User.current = users :admin
  end

  test 'it should not save without an empty name' do
    location = Location.new
    refute location.save
  end

  test 'it should not save with a blank name' do
    location = Location.new(:name => "      ")
    refute location.save
  end

  test 'it should not save another location with the same name if no parent' do
    second_location = Location.new(:name => "Location 1")
    refute second_location.save
  end

  test 'name can be the same if parent is different' do
    assert_difference('Location.count', 2) do
      assert subloc1 = Location.create!(:name => "Building A", :parent_id => taxonomies(:location1).id)
      assert subloc2 = Location.create!(:name => "Building A", :parent_id => taxonomies(:location2).id)
      assert_equal 'Location 1/Building A', subloc1.title
      assert_equal 'Location 2/Building A', subloc2.title
    end
  end

  test 'it should show the name for to_s' do
    location = Location.new :name => "location name"
    assert_equal "location name", location.to_s
  end

  test 'location is valid if ignore all types' do
    location = taxonomies(:location1)
    location.organization_ids = [taxonomies(:organization1).id]
    location.ignore_types = ["Domain", "Hostgroup", "Environment", "User", "Medium", "Subnet", "SmartProxy", "ProvisioningTemplate", "ComputeResource", "Realm"]
    assert location.valid?
  end

  test 'location is valid after fixture mismatches' do
    location = taxonomies(:location1)
    Taxonomy.all_import_missing_ids
    assert location.valid?
  end

  test 'it should return array of used ids by hosts' do
    location = taxonomies(:location1)
    subnet = FactoryGirl.create(:subnet_ipv4, :locations => [location])
    domain = FactoryGirl.create(:domain)
    FactoryGirl.create(:host,
                       :compute_resource => compute_resources(:one),
                       :domain           => domain,
                       :environment      => environments(:production),
                       :location         => location,
                       :medium           => media(:one),
                       :operatingsystem  => operatingsystems(:centos5_3),
                       :owner            => users(:scoped),
                       :puppet_proxy     => smart_proxies(:puppetmaster),
                       :realm            => realms(:myrealm),
                       :subnet           => subnet,
                       :organization     => nil)
    FactoryGirl.create(:os_default_template,
                       :provisioning_template  => templates(:mystring2),
                       :operatingsystem  => operatingsystems(:centos5_3),
                       :template_kind    => TemplateKind.find_by_name('provision'))
    # run used_ids method
    used_ids = location.used_ids
    # get results from Host object
    environment_ids = Host.where(:location_id => location.id).uniq.pluck(:environment_id).compact
    hostgroup_ids = Host.where(:location_id => location.id).uniq.pluck(:hostgroup_id).compact
    subnet_ids = Host.where(:location_id => location.id).joins(:primary_interface => :subnet).uniq.pluck(:subnet_id).map(&:to_i).compact
    domain_ids = Host.where(:location_id => location.id).joins(:primary_interface => :domain).uniq.pluck(:domain_id).map(&:to_i).compact
    realm_ids = Host.where(:location_id => location.id).uniq.pluck(:realm_id).compact
    medium_ids = Host.where(:location_id => location.id).uniq.pluck(:medium_id).compact
    compute_resource_ids = Host.where(:location_id => location.id).uniq.pluck(:compute_resource_id).compact
    user_ids = Host.where(:location_id => location.id).where(:owner_type => 'User').uniq.pluck(:owner_id).compact
    smart_proxy_ids = Host.where(:location_id => location.id).map {|host| host.smart_proxies.map(&:id)}.flatten.compact.uniq
    provisioning_template_ids = Host.where("location_id = #{location.id} and operatingsystem_id > 0").map {|host| host.provisioning_template.try(:id)}.compact.uniq
    # match to above retrieved data
    assert_equal used_ids[:environment_ids], environment_ids
    assert_equal used_ids[:hostgroup_ids], hostgroup_ids
    assert_equal used_ids[:subnet_ids], subnet_ids
    assert_equal used_ids[:domain_ids], domain_ids
    assert_equal used_ids[:realm_ids], realm_ids
    assert_equal used_ids[:medium_ids], medium_ids
    assert_equal used_ids[:compute_resource_ids], compute_resource_ids
    assert_equal used_ids[:user_ids].sort, user_ids.sort
    assert_equal used_ids[:smart_proxy_ids].sort, smart_proxy_ids.sort
    assert_equal used_ids[:provisioning_template_ids], provisioning_template_ids
    # match to raw fixtures data
    assert_equal used_ids[:environment_ids].sort, [environments(:production).id]
    assert_equal used_ids[:hostgroup_ids], []
    assert_equal used_ids[:subnet_ids], [subnet.id]
    assert_equal used_ids[:domain_ids], [domain.id]
    assert_equal used_ids[:medium_ids], [media(:one).id]
    assert_equal used_ids[:compute_resource_ids], [compute_resources(:one).id]
    assert_equal used_ids[:user_ids], [users(:scoped).id]
    assert_includes used_ids[:smart_proxy_ids].sort, smart_proxies(:puppetmaster).id
    assert_includes used_ids[:smart_proxy_ids].sort, smart_proxies(:realm).id
    assert_equal used_ids[:provisioning_template_ids], [templates(:mystring2).id]
  end

  test 'it should return selected_ids array of selected values only (when types are not ignored)' do
    location = taxonomies(:location1)
    # run selected_ids method
    selected_ids = location.selected_ids
    # get results from taxable_taxonomies
    environment_ids = location.environments.pluck('environments.id')
    hostgroup_ids = location.hostgroups.pluck('hostgroups.id')
    subnet_ids = location.subnets.pluck('subnets.id')
    domain_ids = location.domains.pluck('domains.id')
    medium_ids = location.media.pluck('media.id')
    user_ids = location.users.pluck('users.id')
    smart_proxy_ids = location.smart_proxies.pluck('smart_proxies.id')
    provisioning_template_ids = location.provisioning_templates.pluck('templates.id')
    compute_resource_ids = location.compute_resources.pluck('compute_resources.id')
    # check if they match
    assert_equal selected_ids[:environment_ids].sort, environment_ids.sort
    assert_equal selected_ids[:hostgroup_ids].sort, hostgroup_ids.sort
    assert_equal selected_ids[:subnet_ids].sort, subnet_ids.sort
    assert_equal selected_ids[:domain_ids].sort, domain_ids.sort
    assert_equal selected_ids[:medium_ids].sort, medium_ids.sort
    assert_equal selected_ids[:user_ids].sort, user_ids.sort
    assert_equal selected_ids[:smart_proxy_ids].sort, smart_proxy_ids.sort
    assert_equal selected_ids[:provisioning_template_ids].sort, provisioning_template_ids.sort
    assert_equal selected_ids[:compute_resource_ids].sort, compute_resource_ids.sort
    # match to manually generated taxable_taxonomies
    assert_equal selected_ids[:environment_ids], [environments(:production).id]
    assert_equal selected_ids[:hostgroup_ids], []
    assert_equal selected_ids[:subnet_ids], [subnets(:one).id]
    assert_equal selected_ids[:domain_ids].sort, [domains(:mydomain).id, domains(:yourdomain).id].sort
    assert_equal selected_ids[:medium_ids], [media(:one).id]
    assert_equal selected_ids[:user_ids], [users(:scoped).id]
    assert_equal selected_ids[:smart_proxy_ids].sort, [smart_proxies(:puppetmaster).id, smart_proxies(:one).id, smart_proxies(:two).id, smart_proxies(:three).id, smart_proxies(:realm).id].sort
    assert_equal selected_ids[:provisioning_template_ids], [templates(:mystring2).id]
    assert_equal selected_ids[:compute_resource_ids], [compute_resources(:one).id]
  end

  test 'it should return selected_ids array of ALL values (when types are ignored)' do
    location = taxonomies(:location1)
    # ignore all types
    location.ignore_types = ["Domain", "Hostgroup", "Environment", "User", "Medium", "Subnet", "SmartProxy", "ProvisioningTemplate", "ComputeResource", "Realm"]
    # run selected_ids method
    selected_ids = location.selected_ids
    # should return all when type is ignored
    assert_equal selected_ids[:environment_ids].sort, Environment.pluck(:id).sort
    assert_equal selected_ids[:hostgroup_ids].sort, Hostgroup.pluck(:id).sort
    assert_equal selected_ids[:subnet_ids].sort, Subnet.pluck(:id).sort
    assert_equal selected_ids[:domain_ids].sort, Domain.pluck(:id).sort
    assert_equal selected_ids[:realm_ids].sort, Realm.pluck(:id).sort
    assert_equal selected_ids[:medium_ids].sort, Medium.pluck(:id).sort
    assert_equal selected_ids[:user_ids].sort, User.pluck(:id).sort
    assert_equal selected_ids[:smart_proxy_ids].sort, SmartProxy.pluck(:id).sort
    assert_equal selected_ids[:provisioning_template_ids].sort, ProvisioningTemplate.pluck(:id).sort
    assert_equal selected_ids[:compute_resource_ids].sort, ComputeResource.pluck(:id).sort
  end

  #Clone
  test "it should clone location with all associations" do
    location = taxonomies(:location1)
    location_dup = location.dup
    location_dup.name = "location_dup_name"
    assert location_dup.save!
    assert_equal location_dup.environment_ids.sort, location.environment_ids.sort
    assert_equal location_dup.hostgroup_ids.sort, location.hostgroup_ids.sort
    assert_equal location_dup.subnet_ids.sort, location.subnet_ids.sort
    assert_equal location_dup.domain_ids.sort, location.domain_ids.sort
    assert_equal location_dup.medium_ids.sort, location.medium_ids.sort
    assert_equal location_dup.user_ids.sort, location.user_ids.sort
    assert_equal location_dup.smart_proxy_ids.sort, location.smart_proxy_ids.sort
    assert_equal location_dup.provisioning_template_ids.sort, location.provisioning_template_ids.sort
    assert_equal location_dup.compute_resource_ids.sort, location.compute_resource_ids.sort
    assert_equal location_dup.realm_ids.sort, location.realm_ids.sort
    assert_equal location_dup.organization_ids.sort, location.organization_ids.sort
  end

  #Audit
  test "it should have auditable_type as Location rather Taxonomy" do
    location = taxonomies(:location2)
    assert location.update_attributes!(:name => 'newname')
    assert_equal 'Location', Audit.unscoped.last.auditable_type
  end

  #Location inheritance tests
  test "inherited location should have correct path" do
    parent = taxonomies(:location1)
    location = Location.create!(:name => "rack1", :parent_id => parent.id)
    assert_equal "Location 1/rack1", location.title
  end

  test "inherited_ids for inherited location" do
    parent = taxonomies(:location1)
    location = Location.create :name => "rack1", :parent_id => parent.id
    # check that inherited_ids of location matches selected_ids of parent
    assert_equal parent.selected_ids, location.inherited_ids
  end

  test "selected_or_inherited_ids for inherited location" do
    parent = taxonomies(:location1)
    location = Location.create :name => "rack1", :parent_id => parent.id
    # add subnet to location
    assert TaxableTaxonomy.create(:taxonomy_id => location.id, :taxable_id => subnets(:two).id, :taxable_type => "Subnet")
    # check that inherited_ids of location matches selected_ids of parent, except for subnet
    location.selected_or_inherited_ids.each do |k,v|
      assert_equal v.uniq, parent.selected_ids[k].uniq unless k == 'subnet_ids'
      assert_equal v.uniq, ([subnets(:two).id] + parent.selected_ids[k].uniq) if k == 'subnet_ids'
    end
  end

  test "used_and_selected_or_inherited_ids for inherited location" do
    parent = taxonomies(:location1)
    subnet = FactoryGirl.create(:subnet_ipv4, :organizations => [taxonomies(:organization1)])
    domain1 = FactoryGirl.create(:domain)
    domain2 = FactoryGirl.create(:domain)
    parent.update_attribute(:domains,[domain1,domain2])
    parent.update_attribute(:subnets,[subnet])
    # we're no longer using the fixture dhcp/dns/tftp proxy to create the host, so remove them
    parent.update_attribute(:smart_proxies,[smart_proxies(:puppetmaster),smart_proxies(:realm)])

    location = Location.create :name => "rack1", :parent_id => parent.id
    FactoryGirl.create(:host,
                       :compute_resource => compute_resources(:one),
                       :domain           => domain1,
                       :environment      => environments(:production),
                       :location         => parent,
                       :organization     => taxonomies(:organization1),
                       :medium           => media(:one),
                       :operatingsystem  => operatingsystems(:centos5_3),
                       :owner            => users(:scoped),
                       :puppet_proxy     => smart_proxies(:puppetmaster),
                       :realm            => realms(:myrealm),
                       :subnet           => subnet)
    FactoryGirl.create(:host,
                       :location         => parent,
                       :domain           => domain2)
    FactoryGirl.create(:os_default_template,
                       :provisioning_template  => templates(:mystring2),
                       :operatingsystem  => operatingsystems(:centos5_3),
                       :template_kind    => TemplateKind.find_by_name('provision'))

    # check that inherited_ids of location matches selected_ids of parent
    location.selected_or_inherited_ids.each do |k,v|
      assert_equal v.sort, parent.used_and_selected_ids[k].sort
    end
  end

  test "need_to_be_selected_ids for inherited location" do
    parent = taxonomies(:location1)
    location = Location.create :name => "rack1", :parent_id => parent.id
    # no hosts were assigned to location, so no missing ids need to be selected
    location.need_to_be_selected_ids.each do |k,v|
      assert v.empty?
    end
  end

  test "multiple inheritence" do
    parent1 = taxonomies(:location1)
    assert_equal [subnets(:one).id], parent1.selected_ids["subnet_ids"]

    # inherit from parent 1
    parent2 = Location.create :name => "floor1", :parent_id => parent1.id
    assert TaxableTaxonomy.create(:taxonomy_id => parent2.id, :taxable_id => subnets(:two).id, :taxable_type => "Subnet")
    assert_equal [subnets(:one).id, subnets(:two).id].sort, parent2.selected_or_inherited_ids["subnet_ids"].sort

    # inherit from parent 2
    location = Location.create :name => "rack1", :parent_id => parent2.id
    assert TaxableTaxonomy.create(:taxonomy_id => parent2.id, :taxable_id => subnets(:three).id, :taxable_type => "Subnet")
    assert_equal [subnets(:one).id, subnets(:two).id, subnets(:three).id].sort, location.selected_or_inherited_ids["subnet_ids"].sort
  end

  test "parameter inheritence with no new parameters on child location" do
    assert_equal [parameters(:location)], taxonomies(:location1).location_parameters

    # inherit parameter from parent
    location = Location.create :name => "floor1", :parent_id => taxonomies(:location1).id
    assert_equal [], location.location_parameters
    assert_equal Hash['loc_param', 'abc'], location.parameters
  end

  test "parameter inheritence with new parameters on child location" do
    assert_equal [parameters(:location)], taxonomies(:location1).location_parameters

    # inherit parameter from parent
    child_location = Location.create :name => "floor1", :parent_id => taxonomies(:location1).id
    assert_equal [], child_location.location_parameters

    # new parameter on child location
    child_location.location_parameters.create(:name => "child_param", :value => "123")

    assert_equal Hash['loc_param', 'abc', 'child_param', '123'], child_location.parameters
  end

  test "parent_params returns only ancestors parameters" do
    assert_equal [parameters(:location)], taxonomies(:location1).location_parameters

    # inherit parameter from parent
    child_location = Location.create :name => "floor1", :parent_id => taxonomies(:location1).id
    assert_equal [], child_location.location_parameters

    # new parameter on child location
    child_location.location_parameters.create(:name => "child_param", :value => "123")

    assert_equal({ 'loc_param' => 'abc' }, child_location.parent_params)
  end

  test "#params_objects should return location parameters" do
    location = Location.create :name => "floor1"
    param = LocationParameter.create(:name => 'name', :value => 'valueable')
    location.location_parameters = [param]
    assert(location.params_objects.include?(param))
  end

  test "#params_objects should return ancestors parameters" do
    location = Location.create :name => "floor1", :parent_id => taxonomies(:location1).id
    assert_equal [], location.location_parameters
    assert_equal [taxonomies(:location1).location_parameters], location.params_objects
  end

  test "cannot delete location that is a parent for nested location" do
    parent1 = taxonomies(:location2)
    Location.create :name => "floor1", :parent_id => parent1.id
    assert_raise Ancestry::AncestryException do
      parent1.destroy
    end
  end

  test "non-admin user is added to location after creating it" do
    user = User.current = users(:one)
    refute user.admin?
    assert location = Location.create(:name => 'new location')
    assert location.users.include?(user)
  end

  test "location name can't be too big to create lookup value matcher over 255 characters" do
    parent = FactoryGirl.create(:location)
    min_lookupvalue_length = "location=".length + parent.title.length + 1
    location = Location.new :parent => parent, :name => 'a' * (256 - min_lookupvalue_length)
    refute_valid location
    assert_equal "is too long (maximum is %s characters)" % (255 - min_lookupvalue_length), location.errors[:name].first
  end

  test "location name can be up to 255 characters" do
    parent = FactoryGirl.create(:location)
    min_lookupvalue_length = "location=".length + parent.title.length + 1
    location = Location.new :parent => parent, :name => 'a' * (255 - min_lookupvalue_length)
    assert_valid location
  end

  test "location should not save when matcher is exactly 256 characters" do
    parent = FactoryGirl.create(:location, :name => 'a' * 245)
    location = Location.new :parent => parent, :name => 'b'
    refute_valid location
    assert_equal _("is too long (maximum is 0 characters)"), location.errors[:name].first
  end

  test ".my_locations returns all locations for admin" do
    as_admin do
      assert_equal Location.unscoped.pluck(:id).sort, Location.my_locations.pluck(:id).sort
    end
  end

  test ".my_locations optionally accepts user as argument" do
    expected = Location.where(:id => users(:one).location_and_child_ids)
    as_admin do
      assert_equal expected.sort, Location.my_locations(users(:one)).pluck(:id).sort
    end
  end

  test ".my_locations returns user's associated locations and children" do
    loc1 = FactoryGirl.create(:location)
    loc2 = FactoryGirl.create(:location, :parent => loc1)
    user = FactoryGirl.create(:user, :locations => [loc1])
    as_user(user) do
      assert_equal [loc1.id, loc2.id].sort, Location.my_locations.pluck(:id).sort
    end
  end
end
