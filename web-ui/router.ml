open Lwt.Infix

(* ocaml-crunch is used to generate the module Static.
   See also https://github.com/aantron/dream/tree/master/example/w-one-binary *)
let loader root path _request =
  Dream.log "In loader. root: %s path: %s" root path;
  match Static.read (Filename.concat root path) with
  | None -> Dream.empty `Not_Found
  | Some asset -> Dream.respond asset

(* All routes relating to GitLab hosted projects. *)
let gitlab_routes gitlab =
  [
    Dream.get "/badge/gitlab/:org/:repo/:branch" (fun request ->
        Controller.Badges.handle
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~branch:(Dream.param request "branch")
          gitlab);
    Dream.get "/gitlab" (fun request -> Dream.redirect request "/");
    Dream.get "/gitlab/:org" (fun request ->
        Controller.Gitlab.list_repos ~org:(Dream.param request "org") gitlab);
    Dream.get "/gitlab/:org/:repo" (fun request ->
        Controller.Gitlab.list_refs
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          gitlab);
    Dream.get "/gitlab/:org/:repo/commit/:hash" (fun request ->
        Controller.Gitlab.list_steps
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~hash:(Dream.param request "hash")
          request gitlab);
    Dream.get "/gitlab/:org/:repo/commit/:hash/variant/:variant" (fun request ->
        Controller.Gitlab.show_step
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~hash:(Dream.param request "hash")
          ~variant:(Dream.param request "variant")
          request gitlab);
    Dream.get "/gitlab/:org/:repo/history/branch/**" (fun request ->
        let fpath = Dream.target request |> Dream.from_path in
        let rec f = function
          | [] -> Dream.empty `Not_Found
          | "branch" :: refs ->
              let gref =
                let branch = String.concat Filename.dir_sep refs in
                `Branch branch
              in
              Controller.Gitlab.list_history
                ~org:(Dream.param request "org")
                ~repo:(Dream.param request "repo")
                ~gref gitlab
          | _ :: paths -> f paths
        in
        f fpath);
    Dream.get "/gitlab/:org/:repo/history/merge-request/:number" (fun request ->
        let gref =
          let id = Dream.param request "number" |> int_of_string in
          `Request id
        in
        Controller.Gitlab.list_history
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~gref gitlab);
    Dream.post "/gitlab/:org/:repo/commit/:hash/variant/:variant/cancel"
      (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Gitlab.cancel_step
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              ~variant:(Dream.param request "variant")
              request gitlab
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/gitlab/:org/:repo/commit/:hash/variant/:variant/rebuild"
      (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Gitlab.rebuild_step
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              ~variant:(Dream.param request "variant")
              request gitlab
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/gitlab/:org/:repo/commit/:hash/cancel" (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Gitlab.cancel_steps
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              request gitlab
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/gitlab/:org/:repo/commit/:hash/rebuild-failed" (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Gitlab.rebuild_steps ~rebuild_failed_only:true
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              request gitlab
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/gitlab/:org/:repo/commit/:hash/rebuild-all" (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Gitlab.rebuild_steps ~rebuild_failed_only:false
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              request gitlab
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
  ]

let github_routes github =
  [
    Dream.get "/badge/:org/:repo/:branch" (fun request ->
        Controller.Badges.handle
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~branch:(Dream.param request "branch")
          github);
    Dream.get "/github" (fun request -> Dream.redirect request "/");
    Dream.get "/github/:org" (fun request ->
        Controller.Github.list_repos ~org:(Dream.param request "org") github);
    Dream.get "/github/:org/:repo" (fun request ->
        Controller.Github.list_refs
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          github);
    Dream.get "/github/:org/:repo/history/branch/**" (fun request ->
        let fpath = Dream.target request |> Dream.from_path in
        let rec f = function
          | [] -> Dream.empty `Not_Found
          | "branch" :: refs ->
              let gref =
                let branch = String.concat Filename.dir_sep refs in
                `Branch branch
              in
              Controller.Github.list_history
                ~org:(Dream.param request "org")
                ~repo:(Dream.param request "repo")
                ~gref github
          | _ :: paths -> f paths
        in
        f fpath);
    Dream.get "/github/:org/:repo/history/pull/:number" (fun request ->
        let gref =
          let id = Dream.param request "number" |> int_of_string in
          `Request id
        in
        Controller.Github.list_history
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~gref github);
    Dream.get "/github/:org/:repo/commit/:hash" (fun request ->
        Controller.Github.list_steps
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~hash:(Dream.param request "hash")
          request github);
    (* This route will support the upcoming change to add refs to the context of a commit
       For now - we ignore any ref information and treat it as the route above. *)
    Dream.get "/github/:org/:repo/commit/:hash/-/**" (fun request ->
        let target =
          List.hd (Astring.String.cuts ~sep:"/-/" (Dream.target request))
        in
        Dream.redirect request target);
    Dream.get "/github/:org/:repo/commit/:hash/variant/:variant" (fun request ->
        Controller.Github.show_step
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~hash:(Dream.param request "hash")
          ~variant:(Dream.param request "variant")
          request github);
    (* This route will support the upcoming change to add refs to the context of a step
       For now - we ignore any ref information and treat it as the route above. *)
    Dream.get "/github/:org/:repo/commit/:hash/variant/:variant/-/**"
      (fun request ->
        let target =
          List.hd (Astring.String.cuts ~sep:"/-/" (Dream.target request))
        in
        Dream.redirect request target);
    Dream.post "/github/:org/:repo/commit/:hash/variant/:variant/cancel"
      (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Github.cancel_step
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              ~variant:(Dream.param request "variant")
              request github
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/github/:org/:repo/commit/:hash/variant/:variant/rebuild"
      (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Github.rebuild_step
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              ~variant:(Dream.param request "variant")
              request github
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/github/:org/:repo/commit/:hash/cancel" (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Github.cancel_steps
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              request github
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/github/:org/:repo/commit/:hash/rebuild-failed" (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Github.rebuild_steps ~rebuild_failed_only:true
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              request github
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.post "/github/:org/:repo/commit/:hash/rebuild-all" (fun request ->
        Dream.form request >>= function
        | `Ok _ ->
            Controller.Github.rebuild_steps ~rebuild_failed_only:false
              ~org:(Dream.param request "org")
              ~repo:(Dream.param request "repo")
              ~hash:(Dream.param request "hash")
              request github
        | _ ->
            Dream.log "Form validation failed";
            Dream.empty `Bad_Request);
    Dream.get "/api/github/:org/:repo/commit/:hash/variant/:variant"
      (fun request ->
        Api_controller.Github.show_step
          ~org:(Dream.param request "org")
          ~repo:(Dream.param request "repo")
          ~hash:(Dream.param request "hash")
          ~variant:(Dream.param request "variant")
          github);
    Dream.get "/api/github/:org/:repo/commit/:hash" (fun request ->
        let org = Dream.param request "org" in
        let repo = Dream.param request "repo" in
        let hash = Dream.param request "hash" in
        Api_controller.Github.list_steps ~org ~repo ~hash github);
  ]

let create ~github ~gitlab =
  Dream.router
    ([
       Dream.get "/css/ansi.css" (fun _ ->
           Dream.respond
             ~headers:[ ("content-type", "text/css") ]
             View.Common.css);
       Dream.get "/favicon.ico" @@ Dream.static ~loader "/";
       Dream.get "/css/**" @@ Dream.static ~loader "/css";
       Dream.get "/images/**" @@ Dream.static ~loader "/images";
       Dream.get "/js/**" @@ Dream.static ~loader "/js";
       Dream.get "/fonts/**" @@ Dream.static ~loader "/fonts";
       Dream.get "/profile-pictures/**" @@ Dream.static "profile-pictures";
       Dream.get "/" (fun _ ->
           match (github, gitlab) with
           | None, None ->
               Dream.log "No backend available";
               Dream.empty `Internal_Server_Error
           | Some github, None -> Controller.Index.list_orgs "github" github
           | None, Some gitlab -> Controller.Index.list_orgs "gitlab" gitlab
           | Some github, Some gitlab ->
               Controller.Index.list_all_orgs ~github ~gitlab);
       Dream.get "/getting-started" (fun _ ->
           Dream.html @@ Controller.Documentation.getting_started);
       Dream.get "/documentation" (fun _ ->
           Dream.html @@ Controller.Documentation.user_guide);
     ]
    @ (match github with Some github -> github_routes github | None -> [])
    @ match gitlab with Some gitlab -> gitlab_routes gitlab | None -> [])
