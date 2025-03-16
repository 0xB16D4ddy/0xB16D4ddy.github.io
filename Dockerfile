FROM ruby:3.2-slim

RUN apt-get update && apt-get install -y \
    build-essential \       
    gcc \                  
    make \                 
    && rm -rf /var/lib/apt/lists/* 

WORKDIR /srv/jekyll

RUN gem install jekyll bundler

COPY Gemfile Gemfile.lock ./

RUN bundle install --jobs 4 --retry 3

COPY . .

EXPOSE 4000

CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0", "--livereload"]