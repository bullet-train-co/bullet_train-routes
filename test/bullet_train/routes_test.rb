require "test_helper"
require "active_support/core_ext/enumerable"

class BulletTrain::RoutesTest < ActionDispatch::IntegrationTest
  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @mapper = @routes.draw { break self }
  end

  delegate :namespace, :scope, :resources, :resource, :model, to: :@mapper
  # delegate_missing_to :@mapper

  test "it has a version number" do
    assert BulletTrain::Routes::VERSION
  end

  test "basic model routing" do
    model "Project"

    assert_formatted_routes <<~ROUTES
    projects GET    /projects(.:format)          projects#index
             POST   /projects(.:format)          projects#create
 new_project GET    /projects/new(.:format)      projects#new
edit_project GET    /projects/:id/edit(.:format) projects#edit
     project GET    /projects/:id(.:format)      projects#show
             PATCH  /projects/:id(.:format)      projects#update
             PUT    /projects/:id(.:format)      projects#update
             DELETE /projects/:id(.:format)      projects#destroy
    ROUTES
  end

  test "model routing with ruby namespace" do
    model "Projects::Deliverable"

    assert_formatted_routes <<~ROUTES
    projects_deliverables GET    /projects/deliverables(.:format)          projects/deliverables#index
                          POST   /projects/deliverables(.:format)          projects/deliverables#create
 new_projects_deliverable GET    /projects/deliverables/new(.:format)      projects/deliverables#new
edit_projects_deliverable GET    /projects/deliverables/:id/edit(.:format) projects/deliverables#edit
     projects_deliverable GET    /projects/deliverables/:id(.:format)      projects/deliverables#show
                          PATCH  /projects/deliverables/:id(.:format)      projects/deliverables#update
                          PUT    /projects/deliverables/:id(.:format)      projects/deliverables#update
                          DELETE /projects/deliverables/:id(.:format)      projects/deliverables#destroy
    ROUTES
  end

  test "nested model routes" do
    model "Project" do
      model "Projects::Deliverable"
    end

    assert_formatted_routes <<~ROUTES
             project_deliverables GET    /projects/:project_id/deliverables(.:format)                   projects/deliverables#index
                                  POST   /projects/:project_id/deliverables(.:format)                   projects/deliverables#create
          new_project_deliverable GET    /projects/:project_id/deliverables/new(.:format)               projects/deliverables#new
edit_project_projects_deliverable GET    /projects/:project_id/projects/deliverables/:id/edit(.:format) projects/deliverables#edit
     project_projects_deliverable GET    /projects/:project_id/projects/deliverables/:id(.:format)      projects/deliverables#show
                                  PATCH  /projects/:project_id/projects/deliverables/:id(.:format)      projects/deliverables#update
                                  PUT    /projects/:project_id/projects/deliverables/:id(.:format)      projects/deliverables#update
                                  DELETE /projects/:project_id/projects/deliverables/:id(.:format)      projects/deliverables#destroy
                         projects GET    /projects(.:format)                                            projects#index
                                  POST   /projects(.:format)                                            projects#create
                      new_project GET    /projects/new(.:format)                                        projects#new
                     edit_project GET    /projects/:id/edit(.:format)                                   projects#edit
                          project GET    /projects/:id(.:format)                                        projects#show
                                  PATCH  /projects/:id(.:format)                                        projects#update
                                  PUT    /projects/:id(.:format)                                        projects#update
                                  DELETE /projects/:id(.:format)                                        projects#destroy
    ROUTES

    assert_equal_routing do
      collection_actions = [:index, :new, :create]

      resources :projects do
        scope module: 'projects' do
          resources :deliverables, only: collection_actions
        end
      end

      namespace :projects do
        resources :deliverables, except: collection_actions
      end
    end
  end

  private

  def assert_equal_routing(&block)
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw(&block)

    expected, actual = formatted_routes(routes), formatted_routes

    expected_lines = expected.split("\n").index_by(&:squish)
    actual_lines = actual.split("\n").index_by(&:squish)

    missing_from_expected = expected_lines.keys - actual_lines.keys
    missing_from_actual   = actual_lines.keys - expected_lines.keys

    if missing_from_expected.none? && missing_from_actual.none?
      pass
    else
      flunk <<~EOM
        Expected routes to be equal, but found these differences.

        These are the expected routes:
          #{expected_lines.values_at(*missing_from_expected).join("\n")}

        These were the actual routes:
          #{actual_lines.values_at(*missing_from_actual).join("\n")}

        The full expected route set is:
        #{expected}
      EOM
    end
  end

  def assert_formatted_routes(string)
    routes = formatted_routes.split("\n")
    lines = string.split("\n")
    lines.each do |route|
      assert_includes routes, route
    end
  end

  def formatted_routes(routes = @routes)
    inspector = ActionDispatch::Routing::RoutesInspector.new(routes.routes)
    formatter = ActionDispatch::Routing::ConsoleFormatter::Sheet.new
    inspector.format(formatter)
  end
end
