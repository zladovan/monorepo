# Versioning plugin

Add support for git based version to project.
Version will be created as **BASE_VERSION.COMMIT_DISTANCE**.

Where **BASE_VERSION** comes from last tag in form **ROOT_PROJECT_NAME@BASE_VERSION**.
Where **ROOT_PROJECT_NAME** is name of root project
and **BASE_VERSION** is any string but usually some numbers divided by dot (e.g. 1.0).
It can contain **v** prefix which will be stripped.

>For example project with name **coin** with tag `coin@v1.0` on two commits back
>will have version **1.0.2**

## How to build

```
gradlew clean build
```

## How to use

Include build in your **settings.xml**.

```
includeBuild '${REPOSITORY_ROOT}/tools/gradle-plugins/gradle-versioning-plugin'
```

Apply plugin in your **build.gradle**.

```
plugins {
    id 'com.zlad.gradle.versioning'
}
```
