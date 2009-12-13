= Project: Trellis

Trellis is a component-based Web Application Framework written in Ruby and based on Rack. 
Its main goal is to bring component-driven development to the micro-framework world.
Trellis applications are composed of pages, pages have components, components emit events,
pages and components can listen and handle events. 
Trellis aims to be a (close to) zero-configuration framework 

It draws inspiration from:

Ruby Web Frameworks
===================
* Rails
* Camping
* Merb
* Iowa
* Sinatra

Java Web Frameworks
===================
* Tapesty
* Wicket

Others
======
* Seaside

== Goals 
Accomplished goals are marked with a (*)
- * Pure HTML templates or in-line template creation with Markaby, HAML, erubis, Markdown and Textile
- * To abstract away the request-response nature of web development and replace 
  with events and listeners
- * Reusable, extensible components including invisible components (behavior 
  providers), tags (stateless components) or stateful components
- * Easy component composition and markup inheritance
- * Multi-threading support 
- * Heavy CoC :-) (Convention Over Configuration) ala Rails
- * No static code generation, no generators, just a Ruby file!
- * Component Libraries as Gems
- Solid Ajax support attached to the event model using a single* massively tested
  Ajax framework/toolkit such as JQuery
- Skinnable components a la DotNet. That is the ability to apply a theme to a 
  page and cascade that to the contained components
- Support for continuations in a componentized fashion (maybe)
- CRUD behaviours for Pages/Components and using Datamapper under the covers
- Web-based debugging and administration of the application similar to what
  Seaside provides

== Development Goals (To-do's)

- Keep the core framework in a single file
- Keep the core components in another file
- I have not done anything about exception handling (didn't wanted to litter the
  code base). Currently I'm always sending an HTTP 200 back or I'm just letting 
  the app blow chuncks and showing rack's exception page
- Radius usage is really entrenched in the current component implementation need
  to clean it up
- Currently Trellis uses the Mongrel Rack Adapter. In the near future the 
  particular web server would be configurable (one of the reasons to use Rack)

== Classes

Trellis::Application:: Base case for all Trellis applications
Trellis::Page:: Base class for all application Pages
Trellis::Renderer:: Renders XML/XHTML tags in the markup using Radius 
Trellis::Router:: Encapsulated the base route for a page
Trellis::Component:: Base class for all Trellis components (work in progress)
Trellis::DefaultRouter:: Encapsulates the default routing logic

== <b>Notes</b>:: 

* Event model is pretty shallow right now. Basically events are just
  a convention of how the URLs are interpreted which results on a page method
  being invoked. A given URL contains information about the target page, event, 
  source of the event and possible context values.This information is used to 
  map to a single method in the page.
* Navigation is a la Tapestry; Page methods can return the instance of a 
  injected Page or they can return self in which case the same page is 
  re-rendered.
* Components can register their event handlers with the page. The page wraps the
  event handlers of the contained components and dispatches the events to the 
  component instance. 
* Currently the Application is a single object, the multi-threading (which I had 
  nothing to do with is provided by Rack) happens in the request dispatching. 
* Trellis is not a managed framework like Tapestry, in that sense it is more like 
  Wicket. Pages instances are just created when needed, there is no pooling, 
  or any of the complexity involved in activating/passivating objects to a pool.

== Installation

* <tt>gem install trellis</tt>

A Trellis application consists of the Application class; a descendant of 
Trellis::Application and one or more pages; descendants of Trellis::Page. The
Application at a minimum needs to declare the starting or home page:

  module Hello
    class HelloWorld < Trellis::Application
      home :home
    end

    class Home < Trellis::Page 
      template do html { body { h1 "Hello World!" }} end
    end
  end

To run the above application simply add the line:

  Hello::HelloWorld.new.start

That will start the application on Mongrel running on port 3000 by default. To 
run on any other port pass the port number to the start method like:

  Hello::HelloWorld.new.start 8282

== Required Gems

rack => http://rack.rubyforge.org
mongrel => http://mongrel.rubyforge.org
radius => http://radius.rubyforge.org
builder => http://builder.rubyforge.org
paginator => http://paginator.rubyforge.org
extensions => http://extensions.rubyforge.org
haml => http://haml.hamptoncatlin.com
markaby => http://code.whytheluckystiff.net/markaby
nokogiri => http://nokogiri.org/
facets => http://facets.rubyforge.org/
directory_watcher => http://rubyforge.org/projects/codeforpeople
erubis => http://www.kuwata-lab.com/erubis/

== LICENSE:

(The MIT License)

Copyright &169;2001-2010 Integrallis Software, LLC.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

== Contact

Author::     Brian Sam-Bodden & the Folks at Integrallis
Email::      bsbodden@integrallis.com
Home Page::  http://trellisframework.org
License::    MIT Licence (http://www.opensource.org/licenses/mit-license.html)