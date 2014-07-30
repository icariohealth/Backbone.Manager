var gulp = require('gulp');
var gutil = require('gulp-util');
var coffee = require('gulp-coffee');
var sourcemaps = require('gulp-sourcemaps');

var paths = {
  scripts: ['./src/*.coffee'],
  testScripts: ['./test/src/*.coffee']
};

gulp.task('coffee', function(){
  gulp.src(paths.scripts)
    .pipe(sourcemaps.init())
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('./lib'))
});

gulp.task('test-coffee', function(){
  gulp.src(paths.testScripts)
    .pipe(sourcemaps.init())
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('./test/lib'))
});

// Rerun the task when a file changes
gulp.task('watch', function() {
  gulp.watch(paths.scripts, ['coffee']);
  gulp.watch(paths.testScripts, ['test-coffee'])
});

gulp.task('default', ['watch', 'coffee', 'test-coffee']);
