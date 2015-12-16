---
layout:       post
title:        Simply Secure Rails API
author:       paul_franzen
summary:      If you're attempting to implement a service orientated architecture one of the most daunting tasks can be deciding on a method for securing API endpoints.
image:        http://res.cloudinary.com/wework/image/upload/s--Al86WVSb--/c_fill,fl_progressive,g_face:center,h_1000,q_jpegmini:1,w_1600/v1427921778/engineering/5-ways-to-create-bulletproof-software-bear.jpg
categories:   rails, api, security, engineering
---

**Quick Note:** 

> Hi, you probably have not seen a lot of articles/posts about how organizations secure their content on the Interwebs. I'm guessing this is a symptom of: 
> 
> 1. Fear of exposing specific practices that could put their data / applications at risk.
> 
> 2. Fear of backlash among the development community where misunderstandings and semantic arguments reign supreme. And can label an entire company, or an individual (myself) as incompetent.
> 
> I'd by lying if I said that these fears are not in my mind when authoring this post, but by relegating these topics to back-room-locked-down-hundred-page-decks from security consultants we deny ourselves public and accessible conversations around one of the most important issues in our industry. 
> 
> Working at a company like WeWork, I (We) believe that individual success is exponentially more achievable when you're part of a greater community. 
> 
> This belief can sometimes mean uncomfortable travels in which trust outweighs mistrust and you are willing to take on risk in the interest of greater success for both yourself and your community.
> 
> Ok. Now that's out of the way. What follows is a system/explanation, undoubtedly flawed, but one which We hope will help some folks to understand some security concepts a little better and maybe help them in their journey. 
> 
> Thank you, and as always, comments and feedback are not only welcome, but necessary.



---



If you're attempting to implement a service orientated architecture 
one of the most daunting tasks can be deciding on a method for 
securing API endpoints.

A simple (and obvious) solution is to make every request using an 
API key or something like [Basic HTTP Authentication headers](https://en.wikipedia.org/wiki/Basic_access_authentication).

Something like:

Requesting APP (using the wonderful [Faraday](https://github.com/lostisland/faraday)):

```ruby
  Faraday.new(:url => "https://www.api.io/api/v1/posts") do |faraday|
    faraday.adapter Faraday.default_adapter
    faraday.use Faraday::Request::TokenAuthentication,
    faraday.headers['Content-Type'] = 'application/json'
    faraday.token_auth("1234567cy")
  end
```

Receiving APP:

```ruby
  module Api
    module V1
      class PostsController < ApplicationController
        before_filter :restrict_access

        def index
          @posts = Post.page(1)
          respond_with @posts
        end

        private

        def restrict_access        
          authenticate_or_request_with_http_token do |token, options|          
            ApiKey.exists?(access_token: token)
          end
        end

      end
    end
  end
```

This is a fine system, pleasingly simple and straight-forward.
However, it misses one basic fact about these requests: Most 
are made on behalf of the current **user and not the requesting
application.** 

So a posts controller:

```ruby
  module Api
    module V1
      class PostsController < ApplicationController
        before_filter :restrict_access

        def index
          @posts = current_user.posts.page(1)
          respond_with @posts
        end

        private

        def restrict_access        
          authenticate_or_request_with_http_token do |token, options|          
            ApiKey.exists?(access_token: token)
          end
        end

      end
    end
  end
```

Is, well, a little awkward. Because there's really no way to 
know who the "current_user" is without passing in some extra variable.


#### Enter OAuth.

OAuth especially via [DoorKeeper](https://github.com/doorkeeper-gem/doorkeeper) 
and [Omniauth](https://github.com/intridea/omniauth), is amazing, 
but popping-open new windows (or mobile apps), redirect URIs, tokens, secrets, and the funky 
user experience that often accompany them can be a bit too much
ceremony especially if you're connecting two *trusted* applications.

#### Tokens to the rescue!

Encrypting strings that can be later decrypted (usually obfuscated to a word: Token)
is a concept oft hidden by Wizard-Of-Oz style curtains within frameworks like Rails. 

Just set some random ```secret_base_key``` and you're good to go!

When you dig in, oh boy, *Initialization Vectors*, *Ciphers*, wacky words / bad hacker nicknames, inspiring both dread and awe in the uninitiated. 
But just like any good magic trick deciphering the slight of hand is both empowering and inspiring. 

So let's take a peek behind the curtain.

#### Imagine a scenario

##### Application 1: 
In a more traditional architecture, our Authentication service (id.wework.io for example) would be the OAuth provider.

This service has a login API. For the sake of brevity, it uses [Devise](https://github.com/plataformatec/devise).
This application also utilizes CORS via [Rack CORs](https://github.com/cyu/rack-cors) to allow appropriately configured cross-origin access.

##### It has a user model

```ruby
class User < ActiveRecord::Base
  # Schema
  # Name: string
  # UUID: UUID (primary key)
  # Email
  # Devise password stuff
  devise :database_authenticatable
end
```

##### It has a base API controller

```ruby
module Api
  class ApiController < ApplicationController  
    skip_before_action :verify_authenticity_token
  end
end
```

##### It has a login controller endpoint:

```ruby
module Api
  module V1
    class LoginController < ApiController
      
      def create # POST: /api/v1/login
        @user = User.find_by(email: params[:email])

        if User.authenticate(params[:email], params[:password])
          respond_with: @user.as_json()
        else 
          head 404
        end
      end

    end
  end
end
```

##### It has a users controller

```ruby
module Api
  module V1
    class UsersController < ApiController
      
      def show # GET: /api/v1/users/[UUID]
        @user = User.find_by(uuid: params[:id])

        if @user.present?
          respond_with: @user.as_json()
        else 
          head 404
        end
      end

    end
  end
end
```

---

##### Application 2: 
Social Network (https://network.wework.io)
A rails web application which uses the aforementioned authentication service to log a user in and seed user data.

We want this application to log a user in, persist a "copy" of this user (like any standard OAuth app) and allow that user to create posts.

#### Let's get started

First you want to add a method to the authentication service's User Model. This method encrypts a
user's uuid.

Using ruby's OpenSSL library

```ruby
class User < ActiveRecord::Base
  # Schema
  # name: string
  # uuid: UUID (primary key)
  # email: string
  # Devise password stuff
  devise :database_authenticatable

  def encrypted
    srting_to_encrypt = "#{self.uuid}"
    cipher         =  OpenSSL::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.key     =  ENV['SOME_SECRET_KEY']
    cipher.iv      =  ENV['SOME_SECRET_IV']
    cipher.padding =  1
    encrypted      =  cipher.update(self.uuid) + cipher.final # use only this user's UUID for encryption
    Base64.urlsafe_encode64(encrypted).encode('utf-8')
  end
end
```

Look at this bonkers encrypted method! It's pretty hard to figure out what's going on here. And to be fair, it's way outside 
the norm of ordinary, MVC style web development. So lets go through it line by line.

#### Line 1
```ruby
cipher =  OpenSSL::Cipher.new('aes-256-cbc')
```

The argument 'aes-256-cbc' is a hyphenated description of components of the cipher. 

1. "aes" is the name of the encryption algorithm. In this case, its an acronym for [Advanced Encryption Standard](http://aesencryption.net/).

2. 256 is the number of bits of the key used in the algorithm. You'll usually see 128 or 256. Practically, this means that the key is "large" enough that it cannot be feasibly broken via a brute force attack (it would take foooooorrreeeevvvveeeerrr) . 

3. cbc stands for "cipher block chaining" and is the mode by which the aes algorithm encrypts the data. Its most commonly compared to the ecb [electronic code book](http://searchsecurity.techtarget.com/definition/Electronic-Code-Book). 
Its generally preferred to use cbc because ebc may expose pieces of the actual key in the encrypted string when encrypting smaller pieces of data. 

More in-depth documentation is [available here](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html). 

---

#### Line 2
```ruby
cipher.encrypt # cipher.decrypt
```

Since you instantiate a "decipher" the same as a cipher, this line lets the instance know that we intend to use it for encryption rather than decryption.

---

#### Line 3
```ruby
cipher.key =  ENV['SOME_SECRET_KEY']
```

OK, here's where it starts to get interesting. 
This is the first part of the password that we will shared between applications. 
Its important to create a truly random (or as close to that as possible) key, so consult the [documentation](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html#class-OpenSSL::Cipher-label-Choosing+a+key)
to get something as secure as possible.

---

#### Line 4
```ruby
cipher.iv =  ENV['SOME_SECRET_IV']
```

IV, well this stands for initialization vector. An initialization vector creates an extra layer of security around a key, and is generally used only once per instance of a cipher. 
We're breaking the rules a little here, because our IV will be used only to prevent the accidental exposure of the key in the encrypted payload. 
Consult the [documentation](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html#class-OpenSSL::Cipher-label-Choosing+an+IV) to choose your IV.

---

For both of these (as implied by the code), you'll want to store them outside of version control and in some sort of easily changeable way in case they are ever compromised.

You'll also want to use different values for each environment, i.e. development, test, staging, production.

---

#### Line 5
```ruby
cipher.padding =  1
```

This sets the cipher padding to 1 character. Just kidding! This is a boolean, which ENABLES padding in the cipher.  The short story is that the aes
block cipher algorithm mentioned above requires its input to be an EXACT multiple of the block size. Setting this to 1 allows for variance in the size of the data being encrypted. 
If you're very interested: read the full [documentation](http://ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/OpenSSL/Cipher.html#method-i-padding-3D)

---

#### Line 6
```ruby
encrypted =  cipher.update(self.uuid) + cipher.final
```
This takes the actual data you want to encrypt, in this case the user's 
UUID, and turns is into something that's actually ready to be deciphered.
[Documentation](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html#method-i-final)

---

#### Line 7
```ruby
Base64.urlsafe_encode64(encrypted).encode('utf-8')
```
This is the actual data we want to transform the finalized cipher into so that it can be passed safely via a query string or form data. Only over SSL, of course :)

---

After our authentication application's user model has an encrypted method we can modify the: 

##### Authentication Application's User's controller

```ruby
module Api
  module V1
    class LoginController < ApiController
      
      def create # POST: /api/v1/login
        @user = User.find_by(email: params[:email])

        if User.authenticate(params[:email], params[:password])
          respond_with: @user.as_json(methods: [:encrypted])
        else 
          head 404
        end
      end

    end
  end
end
```

Now that our authentication application is prepped to return encrypted UUIDs (when provided a valid email and password), we
can create our Social Networking application here's some boilerplate:

##### Our Social Network's user class

```ruby
class User < ActiveRecord::Base
  # Schema
  # name: string
  # uuid: uuid (primary key)
  # email: string

  def self.create_from_authentication_service(email, password)
    begin
      connection =  Faraday.new(url: "https://id.wework.io") do |faraday|
                      faraday.adapter Faraday.default_adapter    
                      faraday.headers['Content-Type'] = 'application/json'
                    end

      response = connection.post("/api/v1/login/", {
                    email: email,
                    password: password
                  }.to_json)

      parsed_body = JSON.parse(response.body)

      User.create({
        uuid:  parsed_body["user"]["uuid"],
        email: parsed_body["user"]["email"],
        name:  parsed_body["user"]["name"]
      })

      parsed_body
    rescue 
      false
    end
  end
end
```

##### Our Social Network login controller

```ruby
class LoginController < ApplicationController

  def new # Get /login
  end

  def create  # Post/login

    user = User.create_from_authentication_service(params[:email], params[:password])

    if user
      render json: user
    else
      redirect new_login_path, error: "Something went wrong!"
    end
  
  end

end

```

##### Our new Social Network login view
```html
<html>
  <head>
    <title>Network</title>
  </head>
  <body>
    <form method="POST" action="<%= create_login_path %>" id="loginForm">
      <input type="text" name="email" placeholder="Email" />
      <input type="password" name="password" placeholder="password" />
      <input type="submit" value="submit" />
    </form>
    <script>
      $("#loginForm").on("submit", function(){
        $.ajax({
          url: $(this).attr("action"),
          method: "POST",
          data: $(this).serialize()
        })
        .success(function(response) {
          localStorage.setItem("e", response.encrypted);
        });
      });
    </script>
  </body>
</html>
```
---

As you can see, this lets you store an encrypted string on the *client* side. And unlike the Master Access Token Approach described at the beginning of this article, 
this token is only valid for this particular user, so the client can be a mobile app or a web front-end so if this token is compromised, its only for this single user. 

Here's the reaaaalllyy important part:

##### Our new Social Network's Application Controller

```ruby
class ApplicationController < ActionController::Base

  protected

  def decrypt(encrypted_uuid)
    begin
      decipher         = OpenSSL::Cipher.new 'aes-256-cbc'
      decipher.decrypt
      decipher.padding = 1
      decipher.key     = ENV['SOME_SECRET_KEY']
      decipher.iv      = ENV['SOME_SECRET_IV']
      decrypted        = cipher.update(Base64.urlsafe_decode64(encrypted_uuid)) + decipher.final
      decrypted
    rescue
      head 403 and return
    end
  end

  def current_user
    if params[:encrypted_user_uuid]
      @current_user ||= User.find_by_uuid( decrypt_uuid(params[:encrypted_user_uuid]) )
    end
  end
  helper_method :current_user

  def require_user
    if !current_user.present?
      head 403
    end
  end

end
```

You'll notice that the ``` decrypted_uuid ``` follows the same pattern as the encryption method. 
As you can probably guess, this runs through the previously documented code, essentially in reverse, and it outputs a recognize-able
uuid that you can use for lookup.

Now our social network can implement a controller like: 

```ruby
class PostsController < ApplicationController
  before_filter :require_user

  def index
    render json: current_user.posts
  end

end
```

Which can serve to either a client web app or a mobile app as long as you pass ```encrypted_user_uuid``` as a parameter in each request.


### Great Success!

---

#### Lets Go The Extra Mile

This implementation is pretty solid, and satisfies the basic needs for locking requests, but it leaves much room for improvement. 

Let's look at some of the problems, and try to fix them w/o making everything really complicated.

#### Problem 1: Can't revoke these tokens individually

By using ENV variables for the IV and Key we can revoke permissions, but only for "all users" not individual users. 


Lets fix this!

##### Our modified Social Network's user class

```ruby
class User < ActiveRecord::Base
  # Schema
  # name: string
  # uuid: uuid (primary key)
  # email: string
  # token: string
  def before_validation :create_token

  def create_token
    self.token ||= SecureRandom.urlsafe_base64(nil, false)
  end

  def self.create_from_authentication_service(email, password)
    begin
      connection =  Faraday.new(url: "https://id.wework.io") do |faraday|
                      faraday.adapter Faraday.default_adapter    
                      faraday.headers['Content-Type'] = 'application/json'
                    end

      response = connection.post("/api/v1/login/", {
                    email: email,
                    password: password
                  }.to_json)

      parsed_body = JSON.parse(response.body)

      user = User.create({
        uuid:  parsed_body["user"]["uuid"],
        email: parsed_body["user"]["email"],
        name:  parsed_body["user"]["name"]
      })

      {user: user, payload: parsed_body}
    rescue 
      false
    end
  end
end
```

Here we're creating a random token, per user, which we can alter / delete if the top level ever becomes compromised.


##### Our modified Social Network login view
```html
<html>
  <head>
    <title>Network</title>
  </head>
  <body>
    <form method="POST" action="<%= create_login_path %>" id="loginForm">
      <input type="text" name="email" placeholder="Email" />
      <input type="password" name="password" placeholder="password" />
      <input type="submit" value="submit" />
    </form>
    <script>
      $("#loginForm").on("submit", function(){
        $.ajax({
          url: $(this).attr("action"),
          method: "POST",
          data: $(this).serialize()
        })
        .success(function(response) {
          localStorage.setItem("e", response.payload.encrypted);
          localStorage.setItem("t", response.user.token);
        });
      });
    </script>
  </body>
</html>
```

##### Our new Social Network's Application Controller

```ruby
class ApplicationController < ActionController::Base

  protected

  def decrypt(encrypted_uuid)
    begin
      decipher         = OpenSSL::Cipher.new 'aes-256-cbc'
      decipher.decrypt
      decipher.padding = 1
      decipher.key     = ENV['SOME_SECRET_KEY']
      decipher.iv      = ENV['SOME_SECRET_IV']
      decrypted        = cipher.update(Base64.urlsafe_decode64(encrypted_uuid)) + decipher.final
      decrypted
    rescue
      head 403 and return
    end
  end

  def current_user
    if params[:encrypted_user_uuid] && params[:token]
      @current_user ||= User.find_by(uuid: decrypt_uuid(params[:encrypted_user_uuid]), token: params[:token])
    end
  end
  helper_method :current_user

  def require_user
    if !current_user.present?
      head 403
    end
  end

end
```

Now we are accessing this user based on an easily revoke-able token in the client app.

---

##### Problem 2: Decoding

Since we are encoding a uuid and the encrypted uuid is stored in the client its *technically possible* ([the best kind of possible](https://www.youtube.com/watch?v=hou0lU8WMgo)) for a nefarious person to gather up 
enough uuids and their encrypted counterparts to break our encryption. 

So lets add some additional values to our encryption for parsing.

Our Authentication service's modified User class

```ruby
class User < ActiveRecord::Base
  # Schema
  # name: string
  # uuid: UUID (primary key)
  # email: string
  # extra_lock: string
  # Devise password stuff
  devise :database_authenticatable
  before_validation: ensure_extra_lock

  def ensure_extra_lock
    self.extra_lock ||= ["Key 1", "Key 2", "Key 3", "Key 4"].sample # These probably shouldn't be real words
  end

  def encrypted
    srting_to_encrypt = "#{self.uuid}|||#{self.extra_lock}"
    cipher         =  OpenSSL::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.key     =  ENV['SOME_SECRET_KEY']
    cipher.iv      =  ENV['SOME_SECRET_IV']
    cipher.padding =  1
    encrypted      =  cipher.update(srting_to_encrypt) + cipher.final
    Base64.urlsafe_encode64(encrypted).encode('utf-8')
  end
end
```

As you can see we've added a little extra data to the string that we are encrypting.

Now on the client application:

```ruby
class ApplicationController < ActionController::Base

  protected

  def decrypt(encrypted_uuid)
    begin
      decipher         = OpenSSL::Cipher.new 'aes-256-cbc'
      decipher.decrypt
      decipher.padding = 1
      decipher.key     = ENV['SOME_SECRET_KEY']
      decipher.iv      = ENV['SOME_SECRET_IV']
      decrypted        = cipher.update(Base64.urlsafe_decode64(encrypted_uuid)) + decipher.final
      decrypted_split  = decrypted.split("|||")
      unless ["Key 1", "Key 2", "Key 3", "Key 4"].include?(decrypted_split[1])
        raise
      end
      decrypted_split[0]
    rescue
      head 403 and return
    end
  end

  def current_user
    if params[:encrypted_user_uuid] && params[:token]
      @current_user ||= User.find_by(uuid: decrypt_uuid(params[:encrypted_user_uuid]), token: params[:token])
    end
  end
  helper_method :current_user

  def require_user
    if !current_user.present?
      head 403
    end
  end

end
```

Since our apps know what keys are valid and know precisely how they are encrypted. 
Its fairly simple to add this extra little layer which would make brute forcing via many uuids *practically* impossible.

## Cautions and Caveats:

As with any security implementation, there are ways to make this more robust and (probably) more than a few different through it. 
You should always take your time and implement the system that is best for your needs and take into account what you're securing, 
highly classified documents vs payment information vs access to profile information and make your decision/implementation appropriately.

---
