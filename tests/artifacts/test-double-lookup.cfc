component {
    function testDoubleArrayLookup() {
        var myArray = [1, 2, 3];
        var result = [];
        cfloop(array=myArray, index="local.i") {
            // Double lookup - same array access twice
            if (myArray[i] > 1) {
                arrayAppend(result, myArray[i]);
            }
        }
        return result;
    }
    
    function testDoubleStructLookup() {
        var myStruct = {a: 1, b: 2, c: 3};
        var result = [];
        cfloop(collection=myStruct, item="local.key") {
            // Double lookup - accessing same key twice
            if (myStruct[key] > 1) {
                arrayAppend(result, myStruct[key]);
            }
        }
        return result;
    }
}
