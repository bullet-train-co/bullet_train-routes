# Bullet Train Routes
Bullet Train Routes provides a vastly simplified method for defining shallow, nested resource routes in Rails applications when modules and namespaces are involved. We do this by introducing a `model` method to the Rails routing DSL, which serves as an interchangable substitute for the `resources` method.

## Why?
As Rails applications grow and developers start reaching for tools like modules and namespaces to organize their domain model, it can be incredibly challenging to generate sensible routes and URLs using the traditional Rails routing DSL. 

For example, if you've got a `Project` model and a `Projects::Deliverable` model nested under it, the following would be sensible URLs:

 - `/projects/1` for a project show page.
 - `/projects/1/deliverables` for the deliverables index page.
 - `/projects/deliverables/2` for a deliverable show page.

To produce these URLs with the standard Rails routing DSL, you'll end up with the following:

### ❌ &nbsp; Hard Example
```ruby
collection_actions = [:index, :new, :create]

resources :projects do
  scope module: 'projects' do
    resources :deliverables, only: collection_actions
  end
end

namespace :projects do
  resources :deliverables, except: collection_actions
end
```

This is just one example, and not even the most complicated. Previously [we published a comprehensive blog post](https://blog.bullettrain.co/nested-namespaced-rails-routing-examples/) to try and help developers with various examples like this, but there was no helping that the resulting code would be very difficult for the next developer to understand and maintain later.

> In addition to all of this, trying to automatically generate these routes proved to be one of the most complicated and error-prone pieces of [Super Scaffolding](https://bullettrain.co/docs/super-scaffolding).

With Bullet Train Routes, the example above can be simplified like so:

### ✅ &nbsp; Easy Example
```ruby
model "Project" do 
  model "Projects::Deliverable"
end
```

## Other Examples
Here are additional before and after comparisons inspired by some of the examples in [our original blog post](https://blog.bullettrain.co/nested-namespaced-rails-routing-examples/).

### `Projects::Deliverable` and `Objective` Nested Under It

If you're nesting a resource that isn't in the same namespace, you traditionally end up with a route definition that looks like this:

### ❌ &nbsp; Hard Example
```ruby
namespace :projects do
  resources :deliverables
end

resources :projects_deliverables, path: 'projects/deliverables' do
  resources :objectives
end
```

This produces the following URLs:

- `/projects/deliverables/1` for a deliverable show view.
- `/projects/deliverables/1/objectives` for the objectives index view.
- `/objectives/2` for an objective show view.

With Bullet Train Routes, you can simply define this as:

### ✅ &nbsp; Easy Example
```ruby
model "Projects::Deliverable" do 
  model "Objective"
end
````

### `Orders::Fulfillment` and `Shipping::Package` Nested Under It

If you're nesting a resource across namespaces, you'll end up with a route definition that looks like this:

### ❌ &nbsp; Hard Example
```ruby
namespace :orders do
  resources :fulfillments
end

resources :orders_fulfillments, path: 'orders/fulfillments' do
  namespace :shipping do
    resources :packages
  end
end
```

This produces the following URLs:

- `/orders/fulfillments/1` for a fulfillment show view.
- `/orders/fulfillments/1/shipping/packages` for the packages index view.
- `/shipping/packages/2` for a package show view.

With Bullet Train Routes, you can simply define this as:

### ✅ &nbsp; Easy Example
```ruby
model "Orders::Fulfillment" do 
  model "Shipping::Package"
end
````

## Interoperability

You can use the `model` method the same way you would the `resources` method, like so:

```ruby
namespace :account do 
  model "Site", concerns: [:sortable] do 
    collection do 
      get :search
    end

    member do 
      post :publish
    end

    # Even this still works the way you'd expect.
    resources :pages
  end
end
```

## What `model` Draws

Two rules cover every example above:

1. **A model with no `model` parent is drawn at its canonical location.** Its module path becomes namespaces, so `model "Projects::Deliverable"` draws exactly what `namespace :projects { resources :deliverables }` draws.
2. **A model nested inside another `model` is drawn shallowly under its parent.** Its collection actions (`index`, `new`, `create`) nest under the parent, and its member actions (`show`, `edit`, `update`, `destroy`) stay at the child's own canonical location.

Namespaces the parent's path already spells out aren't repeated in the nested path, which is what turns `Project` + `Projects::Deliverable` into `/projects/1/deliverables` rather than `/projects/1/projects/deliverables`.

| Declaration | Collection | Member |
| --- | --- | --- |
| `model "Project"` | `/projects` | `/projects/:id` |
| `model "Projects::Deliverable"` | `/projects/deliverables` | `/projects/deliverables/:id` |
| `Project` › `Projects::Deliverable` | `/projects/:project_id/deliverables` | `/projects/deliverables/:id` |
| `Projects::Deliverable` › `Objective` | `/projects/deliverables/:projects_deliverable_id/objectives` | `/objectives/:id` |
| `Hosting::Site` › `Hosting::Page` | `/hosting/sites/:site_id/pages` | `/hosting/pages/:id` |
| `Orders::Fulfillment` › `Shipping::Package` | `/orders/fulfillments/:orders_fulfillment_id/shipping/packages` | `/shipping/packages/:id` |

The splitting is done with Rails' own `shallow:`, `shallow_path:` and `shallow_prefix:`, so your block is evaluated once and every `resources` option behaves the way it does everywhere else.

## Notes

 - `model` accepts a class name (`"Projects::Deliverable"`), a symbol (`:deliverable`), or the model class itself.
 - A plain `resources` nested inside a nested `model` inherits `shallow: true`, just as it would inside hand-written shallow resources. Pass `shallow: false` if you want it fully nested.
 - A `model` written inside a further block — a `namespace`, `scope`, or `resources` within another model's block — is drawn right there, with that scope applied, instead of being hoisted out as a shallow child. If you want a child's member routes to stay shallow, put the namespace in its name: `model "Extra::Deliverable"`, not `namespace :extra { model "Deliverable" }`.
 - A surrounding `namespace` composes with the model's own namespace, so `namespace :account { model "Account::Site" }` routes to `/account/account/sites`. Name the model `"Site"` inside the namespace, or drop the namespace block.
 - Rails route precedence still applies between declarations. `model "Project"` followed by `model "Projects::Deliverable"` puts `/projects/:id` ahead of `/projects/deliverables`, so declare the deeper model first if you need its collection URL to win.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "bullet_train-routes"
```

And then execute:
```bash
$ bundle
```

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
