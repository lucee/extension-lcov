component {
	
	// Example 1: Double array lookup
	function doubleArrayLookup() {
		var myArray = [1, 2, 3, 4, 5];
		var result = [];
		
		cfloop(array=myArray, index="local.i") {
			// BAD: Looking up myArray[i] twice
			if (myArray[i] > 2) {
				arrayAppend(result, myArray[i] * 2);
			}
		}
		
		return result;
	}
	
	// Example 2: Double struct lookup
	function doubleStructLookup() {
		var myStruct = {a: 1, b: 2, c: 3};
		var result = [];
		
		cfloop(collection=myStruct, item="local.key") {
			// BAD: Looking up myStruct[key] twice
			if (myStruct[key] > 1) {
				arrayAppend(result, myStruct[key] * 10);
			}
		}
		
		return result;
	}
	
	// Example 3: Good - cached lookup
	function cachedArrayLookup() {
		var myArray = [1, 2, 3, 4, 5];
		var result = [];
		
		cfloop(array=myArray, index="local.i") {
			var val = myArray[i]; // GOOD: Cache it
			if (val > 2) {
				arrayAppend(result, val * 2);
			}
		}
		
		return result;
	}
	
	// Example 4: Triple lookup - even worse
	function tripleStructLookup() {
		var data = {x: 5, y: 10, z: 15};
		var total = 0;
		
		cfloop(collection=data, item="local.k") {
			// BAD: Three lookups of data[k]
			if (data[k] > 5) {
				total += data[k];
				echo("Value: " & data[k]);
			}
		}
		
		return total;
	}
	
	// Example 5: Nested struct double lookup
	function nestedStructLookup() {
		var users = {
			john: {age: 30, active: true},
			jane: {age: 25, active: true}
		};
		var result = [];
		
		cfloop(collection=users, item="local.name") {
			// BAD: users[name] accessed multiple times
			if (users[name].active) {
				arrayAppend(result, {
					name: name,
					age: users[name].age
				});
			}
		}
		
		return result;
	}
	
}
