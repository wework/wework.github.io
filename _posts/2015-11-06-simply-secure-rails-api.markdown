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
application. Enter OAuth.

OAuth especially via [DoorKeeper](https://github.com/doorkeeper-gem/doorkeeper) 
and [Omniauth](https://github.com/intridea/omniauth), is great, 
but opening new windows, redirect URIs, tokens, and the funky 
user experience that often accompany them can be a bit too much
ceremony, particularly if you're connecting two trusted applications, 
often times sharing the same base domain.

#### Tokens to the rescue!

Encrypting strings that can be later decrypted (usually obfuscated to a word: Token)
is a concept oft hidden Wizard-Of-Oz style curtains within frameworks like Rails. 

*Initialization Vectors*, *Ciphers*, fancy words and bad hacker nicknames, inspiring both dread and awe in the uninitiated. 
But just like any good magic trick deciphering the slight of hand is both empowering and inspiring.

#### Scenario

##### Application 1: 
Our Authentication service (https://id.wework.io)
In a more traditional architecture, this would be the OAuth provider
This service has a login API. It uses [Devise](https://github.com/plataformatec/devise)
to manage authentication. This application also utilizes CORS via [Rack CORs](https://github.com/cyu/rack-cors).
Allowing the appropriate cross-origin access.

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
A rails web app which uses the authentication service to log a user in and seed user data.
It stores: users (like most OAuth apps), and posts.

##### Login Screen

```html
  <html>
    <head>
      <title>Network</title>
      <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js"></script>
    </head>
    <body>
      <form method="POST" action="https://id.wework.io/api/v1/login/">
        <input type="text" name="email" placeholder="Email" />
        <input type="password" name="password" placeholder="password" />
        <input type="submit" value="submit" />
      </form>
    </body>
  </html>
```

So, how do we get from these simple endpoints and actions, to a functioning ecosystem?
I thought you'd never ask!

First you want to add a method to the authentication service's User Model. This method encrypts a
user's uuid or any column that's unique (or a combination of columns for extra security).

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

Anyone know what this method does? Anyone? Anyone?

That's OK!!

It's pretty much way outside the norm of "ordinary" MVC web development. So lets go through it line by line.


#### Line 1
```ruby
cipher =  OpenSSL::Cipher.new('aes-256-cbc')
```

The argument 'aes-256-cbc' is a hyphenated description of components of the cipher. 

1. "aes" is the name of the encryption algorithm. In this case, its an acronym for [Advanced Encryption Standard](http://aesencryption.net/).

2. 256 is the number of bits of the key used in the algorithm. You'll usually see 128 or 256. Practically, this just means that the key is "large" enough that it cannot be easily broken via a brute force attack. 

3. cbc stands for "cipher block chaining" and is the mode by which the aes algorithm encrypts the data. Its most commonly compared the ecb (electronic code book)[http://searchsecurity.techtarget.com/definition/Electronic-Code-Book]. 
Its generally preferred to use cbc for encoding smaller things, because ebc may expose pieces of the real string in the encrypted string.

Full documentation is available [here](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html). 

---

#### Line 2
```ruby
cipher.encrypt
```

This lets the cipher instance we defined before know that we intend to use it for encryption rather than decryption.

---

#### Line 3
```ruby
cipher.key =  ENV['SOME_SECRET_KEY']
```

OK, here's where it starts to get interesting. 
This is basically the first part of the password that will shared between applications. 
Its important to create a truly random (or as close to that as possible) key, so consult the [documentation](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html#class-OpenSSL::Cipher-label-Choosing+a+key)

---

#### Line 4
```ruby
cipher.iv =  ENV['SOME_SECRET_IV']
```

The iv here, well this stands for initialization vector. An initialization vector creates an extra layer of security around a key, and is generally used only once per instance of a cipher. 
We're breaking the rules a little here, because our IV will be used only to prevent the accidental exposure of the key in the encrypted payload. 
Consult the [documentation](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html#class-OpenSSL::Cipher-label-Choosing+an+IV) to choose your IV.

---

For both of these, as implied by the code, you'll want to store them outside of version control and in some sort of easily changeable way (such as an environment variable) in case the are ever compromised.

You'll also want to use different values for each environment, i.e. development, staging, production.

---

#### Line 5
```ruby
cipher.padding =  1
```

This sets the cipher padding to 1. Just kidding, that would make too much sense! This ENABLES padding in the cipher. The short story is that the aes
block cipher algorithm mentioned above requires its input to be and EXACT multiple of the block size. Read the full [documentation](http://ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/OpenSSL/Cipher.html#method-i-padding-3D)

---

#### Line 6
```ruby
encrypted =  cipher.update(self.uuid) + cipher.final
```
For practical purposes, this is a procedural event in the cipher's life-cycle. It returns the, you guessed it, final remaining data in the cipher object.
Or in more sane terms, something that's ready to be deciphered. [Documentation](http://docs.ruby-lang.org/en/trunk/OpenSSL/Cipher.html#method-i-final)

---

#### Line 7
```ruby
Base64.urlsafe_encode64(encrypted).encode('utf-8')
```
This is the actual return we want to transform the finalized cipher into so that it can be passed safely via a query string or form data. Only over SSL, of course :-)

---

### OK, lets put this to use.

Now that our user model has an encrypted method we can modify the authentication app's 

##### Users controller

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

Now that our authentication application is prepped to return encrypted uuids when provided a valid email and password we can alter our

##### Client application login screen

```html
<html>
  <head>
    <title>Network</title>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js"></script>
  </head>
  <body>
    <form method="POST" action="https://id.wework.io/api/v1/login/" id="loginForm">
      <input type="text" name="email" placeholder="Email" />
      <input type="password" name="password" placeholder="password" />
      <input type="submit" value="submit" />
    </form>
    <script type="text/javascript">
      $("#loginForm").on("submit", function(e){
        e.preventDefault();
        var url = $(this).attr("action");
        var data = $(this).serialize();
        $.ajax({
          url: url,
          type: 'post',
          data: data,
          success: function(response) {
            localStorage.setItem("euuid", response.user.encypted);
          },
          error: function(response){
            alert("Sorry, something went wrong.");
          }
        });
      });
    </script>
  </body>
</html>
```

Using *GASP* jQuery we are able to post to our authentication app (with properly configured CORS) and 
get a response that looks something like this:

```json
{
  user:{
    encrypted: SOME_IMPOSSIBLE_TO_DECIPHER_STRING,
    name: "Jane Doe",
    email: "jane@doe.com"
  }
}
```

We then store the encrypted key to local storage, where we'll use it for subsequent calls to the servers from the client.







