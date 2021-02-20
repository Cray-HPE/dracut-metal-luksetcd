@Library("dst-shared@release/master") _
rpmBuild (
    githubPushRepo: "Cray-HPE/dracut-metal-luksetcd",
    githubPushBranches: "release/.*|main",
    master_branch: "main",
    specfile: "dracut-metal-luksetcd.spec",
    channel: "metal-ci-alerts",
    product: "csm",
    target_node: "ncn",
    fanout_params: ["sle15sp2"],
    slack_notify: ["", "", "false", "false", "true", "true"]
)
