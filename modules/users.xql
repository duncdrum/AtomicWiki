xquery version "3.0";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json="http://www.json.org";

declare option output:method "json";
declare option output:media-type "application/json";

declare function local:find-users() {
    let $query := request:get-parameter("q", ())
    let $users :=
        if ($query) then
            sm:find-users-by-username($query)
        else
            sm:list-users()
    return
        <users>
        {
            map(function($user) { <json:value json:array="true"><value>{$user}</value></json:value> }, $users)
        }
        </users>
};

declare function local:groups() {
        <groups>
        {
            for $group in sm:list-groups()[. = $config:admin-group or starts-with(., "wiki.")]
            order by $group
            return
                <group name="{$group}">
                    <description>{sm:get-group-metadata($group, xs:anyURI("http://exist-db.org/security/description"))}</description>
                    {
                        for $user in sm:get-group-members($group)
                        return
                            <user json:array="true">
                                <id>{$user}</id>
                                <name>
                                {
                                    let $first := sm:get-account-metadata($user, xs:anyURI("http://axschema.org/namePerson/first"))
                                    let $last := sm:get-account-metadata($user, xs:anyURI("http://axschema.org/namePerson/last"))
                                    return
                                        if (exists($first)) then
                                            $first || " " || $last
                                        else
                                            let $name := sm:get-account-metadata($user, xs:anyURI("http://axschema.org/namePerson"))
                                            return
                                                if ($name) then $name else $user
                                }
                                </name>
                            </user>
                    }
                </group>
        }
        </groups>
};

declare function local:create-group() {
    let $id := request:get-parameter("id", ())
    let $id := if (starts-with($id, "wiki.")) then $id else "wiki." || $id
    let $description := request:get-parameter("description", ())
    let $managers := sm:get-group-members($config:admin-group)
    return
        if (sm:group-exists($id)) then
            <error status="error" message="Group {$id} already exists"/>
        else
            <ok status="ok">
                {sm:create-group($id, $managers, $description)}
            </ok>
};

declare function local:add-user() {
    let $id := request:get-parameter("id", ())
    let $group := request:get-parameter("group", ())
    return
        if (sm:user-exists($id)) then
            <ok status="ok">
            {sm:add-group-member($group, $id)}
            </ok>
        else
            <error status="error" message="User {$id} does not exist"/>
};

declare function local:remove-user() {
    let $id := request:get-parameter("id", ())
    let $group := request:get-parameter("group", ())
    return
        sm:remove-group-member($group, $id)
};

let $mode := request:get-parameter("mode", ())
return
    switch ($mode)
        case "create-group" return
            local:create-group()
        case "add-user" return
            local:add-user()
        case "remove-user" return
            local:remove-user()
        case "groups" return
            local:groups()
        default return
            local:find-users()