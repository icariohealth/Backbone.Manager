var coffee = require('gulp-coffee');
var gulp = require('gulp');
var gutil = require('gulp-util');
var header = require('gulp-header');
var rename = require('gulp-rename');
var rimraf = require('gulp-rimraf');
var sourcemaps = require('gulp-sourcemaps');
var stripCode = require('gulp-strip-code');
var uglify = require('gulp-uglify');

var paths = {
  scripts: ['./src/*.coffee','./test/src/*.coffee']
};

/* DEVELOP */

gulp.task('coffee', function(){
  gulp.src(paths.scripts)
    .pipe(sourcemaps.init())
      .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('./out'))
});

// Rerun the task when a file changes
gulp.task('watch', function() {
  gulp.watch(paths.scripts, ['coffee']);
});

/* RELEASE */

gulp.task('wipe-release-dir', function() {
  gulp.src('./release/*', { read: false })
    .pipe(rimraf());
});

var banner = ['/**',
  ' * <%= pkg.name %> - <%= pkg.description %>',
  ' * @version v<%= pkg.version %>',
  ' * @link <%= pkg.homepage %>',
  ' * @author <%= pkg.author %>',
  ' * @license <%= pkg.license %>',
  ' */',
  ''].join('\n');

gulp.task('release-js', function(){
  var pkg = require('./package.json');

  gulp.src('./src/*.coffee')
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(stripCode({
      start_comment: 'gulp-strip-release',
      end_comment: 'end-gulp-strip-release'
    }))
    .pipe(header(banner, {pkg: pkg}))
    .pipe(gulp.dest('./release'));
});

gulp.task('release-js-min', function(){
  gulp.src(['./release/*.js','!./release/*-min.js'])
    .pipe(sourcemaps.init())
      .pipe(uglify())
      .pipe(rename({suffix: '-min'}))
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest('./release'));
});

gulp.task('default', ['watch', 'coffee']);
gulp.task('release', ['wipe-release-dir', 'release-js', 'release-js-min']);
