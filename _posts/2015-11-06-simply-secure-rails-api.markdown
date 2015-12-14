---
layout:       post
title:        Simply Secure Rails API
author:       Paul Franzen
summary:
image:        http://res.cloudinary.com/wework/image/upload/s--Al86WVSb--/c_fill,fl_progressive,g_face:center,h_1000,q_jpegmini:1,w_1600/v1427921778/engineering/5-ways-to-create-bulletproof-software-bear.jpg
categories:   rails, api, security
---

If you're attempting to implement a service orientated architecture 
one of the most daunting tasks can be deciding on a method for 
securing API endpoints.

A simple (and obvious) solution is to make every request using an 
API key or something like [Basic HTTP Authentication headers](https://en.wikipedia.org/wiki/Basic_access_authentication).

Something like:

Requesting APP (using the wonderful Faraday):

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
However, it misses one basic fact about these requests: Most of them 
are made on behalf of the current user and not the requesting
application. 

So a posts controller like this:

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
but popping opening new windows (or mobile apps), redirect URIs, tokens, secrets, and the funky 
user experience that often accompany them can be a bit too much
ceremony especially if you're connecting two trusted applications.

#### Tokens to the rescue!

Encrypting strings that can be later decrypted (usually obfuscated to a word: Token)
is a concept oft hidden by Wizard-Of-Oz style curtains within frameworks like Rails. 

Just Set some random ```secret_base_key``` and you're good to go!

When you dig in, oh boy, *Initialization Vectors*, *Ciphers*, wacky words / bad hacker nicknames, inspiring both dread and awe in the uninitiated. 
But just like any good magic trick deciphering the slight of hand is both empowering and inspiring. 

So let's take a peek behind the curtain.

#### Imagine a scenario

##### Application 1: 
Our Authentication service (https://id.wework.io)
In a more traditional architecture, this would be the OAuth provider.

This service has a login API. For the sake of brevity, it uses [Devise](https://github.com/plataformatec/devise)
to manage users and password. This application also utilizes CORS via [Rack CORs](https://github.com/cyu/rack-cors).
Allowing appropriately configured cross-origin access.

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

        if @user.present? && @user.valid_password?(params[:password])
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
  # Name: string
  # UUID: UUID (primary key)
  # Email
  # Devise password stuff
  devise :database_authenticatable

  def encrypted
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

Look at this bonkers method! It's pretty hard to figure out what's going on here. And to be fair it's outside 
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

Anyway, like electricity, you needn't full understand these modes to use them.
But full documentation is always [available](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html). 

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

For both of these, as implied by the code, you'll want to store them outside of version control and in some sort of easily changeable way in case they are ever compromised.

You'll also want to use different values for each environment, i.e. development, test, staging, production.

---

#### Line 5
```ruby
cipher.padding =  1
```

This sets the cipher padding to 1 character. Just kidding! This is a boolean, which ENABLES padding in the cipher.  The short story is that the aes
block cipher algorithm mentioned above requires its' input to be an EXACT multiple of the block size. Setting this to 1 allows for variance in the size of the data being encrypted. 
If you're very interested: read the full [documentation](http://ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/OpenSSL/Cipher.html#method-i-padding-3D)

---

#### Line 6
```ruby
encrypted =  cipher.update(self.uuid) + cipher.final
```
This takes the actual data you want to encrypt, in this case the user's 
UUID, and turns is into something that's actually ready to be deciphered. For practical purposes, calling .final a procedural event in the cipher's life-cycle. 
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

        if @user.present? && @user.valid_password?(params[:password])
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
  # Name: string
  # UUID: UUID (primary key)
  # Email

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
        name:  parsed_body["user"]["name"],
      })
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
      cookies.signed[:uuid] = user.uuid
      redirect_to "some home", notice: "Great Success!"
    else
      redirect new_login_path, error: "Something went wrong!"
    end
  
  end

end

```

##### Our Social Network application controller

```ruby
class ApplicationController < ActionController::Base
  
  def current_user
    @current_user ||= User.find_by(uuid: cookies.signed[:uuid])
  end
  helper_method :current_user

end

```

##### Our new Social Network login view
```html
<html>
  <head>
    <title>Network</title>
  </head>
  <body>
    <form method="POST" action="<%= create_login_path %>">
      <input type="text" name="email" placeholder="Email" />
      <input type="password" name="password" placeholder="password" />
      <input type="submit" value="submit" />
    </form>
  </body>
</html>
```
---

Here's the important part:

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

### Great Success!

---

##### Cautions and Caveats:

As with any security implementation, there are ways to make this more robust and (probably) more than a few different through it. 
You should always take your time and implement the system that is best for your needs and take into account what you're securing, 
highly classified documents vs payment information vs access to profile information and make your decision appropriately.

I hope you found this enlightening and happy lock downs!

---












