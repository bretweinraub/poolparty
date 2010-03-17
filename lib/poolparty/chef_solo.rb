require "fileutils"

module PoolParty
  class ChefSolo < Chef
    dsl_methods :repo 

    private
    def chef_bin
      "chef-solo"
    end

    # The NEW actual chef resolver.
    def build_tmp_dir
      base_directory = tmp_path/"etc"/"chef"
      roles_dir = "#{base_directory}/roles"
      FileUtils.rm_rf base_directory
      puts "Copying the chef-repo into the base directory from #{repo}"
      
      if File.directory?(repo)
        if File.exist?(base_directory)
          # First remove the directory
          FileUtils.remove_entry base_directory, :force => true
        end
        FileUtils.cp_r "#{repo}/.", base_directory 
      else
        raise "#{repo} chef repo directory does not exist"
      end
      puts "Creating the dna.json"
      attributes.to_dna [], base_directory/"dna.json", {:run_list => ["role[#{cloud.name}]"]}
      write_solo_dot_rb
      # Make sure the roles directory exists
      FileUtils.mkdir_p roles_dir
      write_chef_role_json "#{roles_dir}/#{cloud.name}.json"
    end
    
    def write_solo_dot_rb(to=tmp_path/"etc"/"chef"/"solo.rb")
      content = <<-EOE
cookbook_path     ["/etc/chef/site-cookbooks", "/etc/chef/cookbooks"]
role_path         "/etc/chef/roles"
log_level         :info
      EOE

      File.open(to, "w") do |f|
        f << content
      end
    end
    
    def write_chef_role_json(to=tmp_path/"etc"/"chef"/"dna.json")

      # Add the parent name and the name of the cloud to
      # the role for easy access in recipes.
      pp = {
        :poolparty => {
            :parent_name => cloud.parent.name,
            :name => cloud.name,
        }
      }

      override_attributes.merge! pp
      ca = ChefAttribute.new({
        :name => cloud.name,
        :json_class => "Chef::Role",
        :chef_type => "role",
        :default_attributes => attributes.init_opts,
        :override_attributes => override_attributes.init_opts,
        :description => description
      })
      ca.to_dna _recipes.map {|a| File.basename(a) }, to
    end
  end
end
