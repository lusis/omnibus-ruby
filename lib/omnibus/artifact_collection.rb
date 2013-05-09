
module Omnibus

  # This class represents a collection of packages and implements metadata
  # generation for a multi-platform build matrix release. This class assumes
  # that your build automation tool will copy artfacts for release as
  #
  #     BUILD_CONFIGURATION/pkg/ARTIFACT
  #
  # This will be the case if you are using jenkins multiconfiguration jobs with
  # a copy artifacts build step for your release job.
  #
  # @todo document project.json and project-platform-names.json
  class ArtifactCollection

    attr_reader :project
    attr_reader :config

    # @param project [String] name of the omnibus project to release.
    # @option config [String] :build_version the version of the project to
    #   release.
    # @option config [String] :ignore_missing_packages whether to fail when
    #   packages are not found for all platforms (default: `false`).
    def initialize(project, config)
      @project = project
      @config = config
    end

    # @return [String] JSON representation of the project's map between build and install platforms.
    # @example Chef RPMs are built on CentOS but installable on SUSE:
    #   {
    #     "build_os=centos-5,machine_architecture=x64,role=oss-builder": [
    #         [
    #             "el",
    #             "5",
    #             "x86_64"
    #         ],
    #         [
    #             "sles",
    #             "11.2",
    #             "x86_64"
    #         ]
    #     ],
    def platform_map_json
      IO.read(File.expand_path("../#{project}.json", __FILE__))
    end

    # @return [Hash] the project's map between build and install platforms.
    # @example Chef RPMs are built on CentOS but installable on SUSE:
    #   {
    #     "build_os=centos-5,machine_architecture=x64,role=oss-builder" => [
    #         [
    #             "el",
    #             "5",
    #             "x86_64"
    #         ],
    #         [
    #             "sles",
    #             "11.2",
    #             "x86_64"
    #         ]
    #     ], # more mappings...
    def platform_map
      JSON.parse(platform_map_json)
    end

    # @return [String] path to the project's JSON file mapping build to install
    #   platforms. The file should be named `"#{project}-platform-names.json"`
    def platform_name_map_path
      File.expand_path("../#{project}-platform-names.json", __FILE__)
    end

    # @return [String] JSON string mapping platform short names to long names
    # @example This data drives the installation page for chef-client:
    #   {
    #      "el" : "Enterprise Linux",
    #      "debian" : "Debian",
    #      "mac_os_x" : "OS X",
    #      "ubuntu" : "Ubuntu", 
    #      "solaris2" : "Solaris",
    #      "sles" : "SUSE Enterprise",
    #      "suse" : "openSUSE",
    #      "windows" : "Windows"
    #   }
    def platform_name_map_json
      IO.read(platform_name_map_path)
    end

    # @return [String] JSON string mapping platform short names to long names
    # @example This data drives the installation page for chef-client:
    #   {
    #     "el" => "Enterprise Linux",
    #     "debian" => "Debian",
    #     "mac_os_x" => "OS X",
    #     "ubuntu" => "Ubuntu", 
    #     "solaris2" => "Solaris",
    #     "sles" => "SUSE Enterprise",
    #     "suse" => "openSUSE",
    #     "windows" => "Windows"
    #   }
    def platform_name_map
      JSON.parse(platform_name_map_json)
    end

    # @return [Array<String>] relative paths to the packages to release.
    def package_paths
      @package_paths ||= Dir['**/pkg/*'].reject {|path| path.include?("BUILD_VERSION") }
    end

    # @return [Array<Artifact>] a collection of {Omnibus::Artifact Artifact}
    # objects representing each package to be released.
    def artifacts
      artifacts = []
      missing_packages = []
      platform_map.each do |build_platform_spec, supported_platforms|
        if path = package_paths.find { |p| p.include?(build_platform_spec) }
          artifacts << Artifact.new(path, supported_platforms, config)
        else
          missing_packages << build_platform_spec
        end
      end
      error_on_missing_pkgs!(missing_packages)
      artifacts
    end

    # Will warn or error if packages are missing, based on the value of
    # `config[:ignore_missing_packages]` as given to {#initialize}
    # @return [void]
    # @raise [Omnibus::MissingArtifact] if any expected packages are missing
    #   and not configured to ignore missing packages.
    def error_on_missing_pkgs!(missing_packages)
      unless missing_packages.empty?
        if config[:ignore_missing_packages]
          missing_packages.each do |pkg_config|
            # TODO: this should go to $stderr
            puts "WARN: Missing package for config: #{pkg_config}"
          end
        else
          raise MissingArtifact, "Missing packages for config(s): '#{missing_packages.join("' '")}'"
        end
      end
    end
  end
end

