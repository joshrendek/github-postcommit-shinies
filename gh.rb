require 'sinatra'
require 'yaml'
require 'json'
require 'curb'
require 'erubis'

config = YAML::load(Erubis::Eruby.new(File.open('config.yml').read).result)

set :sessions, true
set :logging, true
set :port, 3000
set :gh_user, config['user']
set :gh_token, config['token']
set :gh_api, "https://github.com/api/v2/json/"
set :gh_apiv3, "https://api.github.com/"
set :gh_issue, "issues/show/:user/:repo/:number"
set :gh_add_label, "issues/label/add/:user/:repo/:label/:number"
set :gh_edit_issue, "repos/:user/:repo/issues/:number"
#view_issue = "issues/show/dmsfl/fleet/23"


def get_labels(user, repo, issue)
    endpoint = options.gh_issue.gsub(':user', user).gsub(':repo', repo).gsub(':number', issue)
    c = Curl::Easy.new(options.gh_api + endpoint)
    c.http_auth_types = :basic
    c.username = options.gh_user
    c.password = options.gh_token
    c.perform
    json = JSON.parse(c.body_str)
    json['issue']['labels']
end

def add_label(user, repo, issue, label)
    endpoint = options.gh_add_label.gsub(':user', user).gsub(':repo', repo).gsub(':number', issue).gsub(':label', label)
    c = Curl::Easy.new(options.gh_api + endpoint)
    c.http_auth_types = :basic
    c.username = options.gh_user
    c.password = options.gh_token
    c.perform
    p c.body_str
end

def assign_issue(user, repo, issue, assignee)
    endpoint = options.gh_edit_issue.gsub(':user', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_post(options.gh_apiv3 + endpoint,{:assignee => assignee}.to_json) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
    end
    p curl.body_str
end

get '/test' do
  p 'hello world'
end

post '/' do
    push = JSON.parse(params[:payload])
    repo = push['repository']['name']
    owner = push['repository']['owner']['name']
    push['commits'].each do |c|
        m = c['message']
        issue = m.scan(/[^\#][0-9]+/)
            if issue.size == 1 #only check for other goodies if an issue is mentioned
                begin
                    user = m.scan(/\=[a-zA-Z0-9]+/)[0].split(//)[1..-1].join
                    assign_issue(owner, repo, issue[0], user)
                rescue => e
                  p e.to_s
                end
                labels = m.scan(/\~[a-zA-Z0-9]+/)
                labels.each do |l|
                    add_label(owner, repo, issue[0], l.gsub('~', ''))
                end
            end
    end
end
