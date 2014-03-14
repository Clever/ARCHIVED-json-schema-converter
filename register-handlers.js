if(process.env.COVERAGE) {
    require('coffee-coverage').register({
        path: 'relative',
        basePath: __dirname,
        exclude: ['test', 'examples', 'node_modules', '.git'],
        initAll: true
    });
}
