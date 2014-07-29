var gulp = require('gulp');
var gutil = require('gulp-util');
var coffee = require('gulp-coffee');
var sourcemaps = require('gulp-sourcemaps');

gulp.task('default', function(){
});

gulp.task('coffee', function(){
  gulp.src('./src/*.coffee')
    .pipe(sourcemaps.init())
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('./lib'))
});
