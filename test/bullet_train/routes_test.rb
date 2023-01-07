require "test_helper"
require "active_support/core_ext/enumerable"

class BulletTrain::RoutesTest < ActionDispatch::IntegrationTest
  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @mapper = @routes.draw { break self }
  end

  delegate :draw,  to: :@routes
  delegate :model, to: :@mapper

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

    assert_routing_equal_to do
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

  test "nesting within namespace" do
    model "Projects::Deliverable" do
      model "Objective"
    end

    assert_routing_equal_to do
      namespace :projects do
        resources :deliverables
      end

      resources :projects_deliverables, path: 'projects/deliverables' do
        resources :objectives
      end
    end
  end

  test "nesting resources across namespacing" do
    model "Orders::Fulfillment" do
      model "Shipping::Package"
    end

    assert_routing_equal_to do
      namespace :orders do
        resources :fulfillments
      end

      resources :orders_fulfillments, path: 'orders/fulfillments' do
        namespace :shipping do
          resources :packages
        end
      end
    end
  end

  test "interoperability" do
    draw do
      concern :sortable do
        get "/sortable", to: "sortable#index"
      end

      namespace :account do
        model "Site", concerns: [:sortable] do
          collection do
            get :search
          end

          member do
            post :publish
          end

          resources :pages
        end
      end
    end

    assert_formatted_routes <<~ROUTES
  search_account_sites GET    /account/sites/search(.:format)                  account/sites#search
  publish_account_site POST   /account/sites/:id/publish(.:format)             account/sites#publish
    account_site_pages GET    /account/sites/:site_id/pages(.:format)          account/pages#index
                       POST   /account/sites/:site_id/pages(.:format)          account/pages#create
 new_account_site_page GET    /account/sites/:site_id/pages/new(.:format)      account/pages#new
edit_account_site_page GET    /account/sites/:site_id/pages/:id/edit(.:format) account/pages#edit
     account_site_page GET    /account/sites/:site_id/pages/:id(.:format)      account/pages#show
                       PATCH  /account/sites/:site_id/pages/:id(.:format)      account/pages#update
                       PUT    /account/sites/:site_id/pages/:id(.:format)      account/pages#update
                       DELETE /account/sites/:site_id/pages/:id(.:format)      account/pages#destroy
 account_site_sortable GET    /account/sites/:site_id/sortable(.:format)       account/sortable#index
         account_sites GET    /account/sites(.:format)                         account/sites#index
                       POST   /account/sites(.:format)                         account/sites#create
      new_account_site GET    /account/sites/new(.:format)                     account/sites#new
     edit_account_site GET    /account/sites/:id/edit(.:format)                account/sites#edit
          account_site GET    /account/sites/:id(.:format)                     account/sites#show
                       PATCH  /account/sites/:id(.:format)                     account/sites#update
                       PUT    /account/sites/:id(.:format)                     account/sites#update
                       DELETE /account/sites/:id(.:format)                     account/sites#destroy
    ROUTES
  end

  private

  def assert_routing_equal_to(&block)
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
