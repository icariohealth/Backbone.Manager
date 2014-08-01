var gulp = require('gulp');
var gutil = require('gulp-util');
var coffee = require('gulp-coffee');
var sourcemaps = require('gulp-sourcemaps');
var stripCode = require('gulp-strip-code');

var paths = {
  scripts: ['./src/*.coffee','./test/src/*.coffee']
};

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

gulp.task('release', function(){
  gulp.src('./src/*.coffee')
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(stripCode({
      start_comment: 'gulp-strip-release',
      end_comment: 'end-gulp-strip-release'
    }))
    .pipe(gulp.dest('./release'));
});

gulp.task('default', ['watch', 'coffee']);
