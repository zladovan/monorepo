package com.zlad.gradle.versioning

import org.gradle.api.Plugin
import org.gradle.api.Project

class VersioningPlugin implements Plugin<Project> {

    @Override
    void apply(Project project) {
        project.plugins.apply 'com.palantir.git-version'
        project.version = resolveVersion(project, project.rootProject.name)
    }

    private String resolveVersion(Project project, String name) {
        def details = project.versionDetails(prefix: "${name}@")
        if (details.version == 'unspecified' || details.gitHash.startsWith(details.lastTag)) {
            return 'unspecified'
        } else {
            return "${details.lastTag.replaceAll('^v', '')}.${details.commitDistance}"
        }
    }

}
