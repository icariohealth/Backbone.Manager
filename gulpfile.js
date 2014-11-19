var coffee = require('gulp-coffee');
var coveralls = require('gulp-coveralls');
var gulp = require('gulp');
var gutil = require('gulp-util');
var header = require('gulp-header');
var istanbul = require('gulp-istanbul');
var mocha = require('gulp-mocha');
var rename = require('gulp-rename');
var rimraf = require('gulp-rimraf');
var sourcemaps = require('gulp-sourcemaps');
var stripCode = require('gulp-strip-code');
var uglify = require('gulp-uglify');

var paths = {
  coffees: ['./src/*.coffee','./test/src/*.coffee'],
  javascripts:['./out/*.js','./out/*.js']
};

/* TEST */

gulp.task('mocha', function () {
  return gulp.src('./test/testRunner.js', {read: false})
    .pipe(mocha({
      ignoreLeaks: true,
      reporter: 'nyan'
    }));
});

gulp.task('mocha-istanbul',['coffee'], function(cb){
  gulp.src(['./out/backbone.manager.js'])
    .pipe(istanbul()) // Covering files
    .on('finish', function () {
      gulp.src(['./test/testRunner.js'])
        .pipe(mocha({
          ignoreLeaks: true
        }))
        .pipe(istanbul.writeReports()) // Creating the reports after tests runned
        .on('end', function(){
          gulp.src('./coverage/lcov.info')
            .pipe(coveralls());
          cb();
        });
    });
});

gulp.task('automocha', ['watchCoffees'], function () {
  gulp.watch(paths.javascripts, ['mocha']);
});

/* DEVELOP */

gulp.task('coffee', function(){
  return gulp.src(paths.coffees)
    .pipe(sourcemaps.init())
      .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('./out'));
});

// Rerun the coffee task when a coffee file changes
gulp.task('watchCoffees', ['coffee'], function() {
  gulp.watch(paths.coffees, ['coffee']);
});

/* RELEASE */

gulp.task('wipe-release-dir', function() {
  return gulp.src('./release/*', { read: false })
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

gulp.task('release-js', ['wipe-release-dir'], function(){
  var pkg = require('./package.json');

  return gulp.src('./src/*.coffee')
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(stripCode({
      start_comment: 'gulp-strip-release',
      end_comment: 'end-gulp-strip-release'
    }))
    .pipe(header(banner, {pkg: pkg}))
    .pipe(gulp.dest('./release'));
});

gulp.task('release-js-min', ['release-js'], function(){
  gulp.src(['./release/*.js','!./release/*-min.js'])
    .pipe(sourcemaps.init())
      .pipe(uglify())
      .pipe(rename({suffix: '-min'}))
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest('./release'));
});

gulp.task('default', ['watchCoffees']);
gulp.task('release', ['release-js-min']);
gulp.task('test', ['mocha-istanbul']);
