#include <cstdio>
#include <math.h> 
#include <ctime>
#include <iostream>
using namespace std;

int performanceMeasure1();
int performanceMeasure2();
int performanceMeasure3();
int performanceMeasure4();
int performanceMeasure5();
int countSortSerial1();
int countSortSerial2();
int countSortSerial3();
int countSortSerial4();
int countSortSerial5();

//calculate the countArray or histogram of number of times a key appears
__global__ void histogram(int * c, int * a, int K, int n)
{
//for inputArray of size n
	int entry =  (blockIdx.x + blockIdx.y * gridDim.x ) * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x;
	c[entry] = 0;
//if out of range then return
	if (entry < 0 || entry >= n) return;
//Get the value at the index
	int value = a[entry];
//update the counterArray at the value index by 1
	int *valueCount = &c[value];
	atomicAdd(valueCount, 1);
}

//calculate the prefix sum using a naive stride method
__global__ void naivePrefixSum(int *b, int *c, int k)
{

	int entry = threadIdx.x;
	if (entry < 0 || entry >= k) return;
	b[entry] = c[entry];
	//printf("c %d\n", b[entry]);	
	__syncthreads();
	//naive parallel stride prefix sum
	for(int i = 1; i < k; i *= 2)
	{
		if(entry > i-1) 
		{
			b[entry] = b[entry] + b[entry - i];
		}
		__syncthreads();
	}
	//printf("\nb %d", b[entry]); 
}

//from the prefix sum, place the numbers in the correct postion in the array
__global__ void copyToArray(int * c, int * a, int * b, int Kp, int n)
{
	extern __shared__ int temp[];
	int entry = (blockIdx.x + blockIdx.y * gridDim.x ) * (blockDim.x * blockDim.y) + (threadIdx.y * blockDim.x) + threadIdx.x;
	if (entry < 0 || entry >= n) return; 
   //get value at the inputArray at an index
	int value = a[entry];
   //get the index for the value 
	int index = atomicAdd(&c[value], -1);
	b[index-1] = value;
}


int main() {


//Start Debug Test
	printf("\nDebug Start\n");
///Test n elements with certain number of keys
	const int n = 1024;
	const int keys = 257;
//Setup Array on host and device
	int i_h[n] = {0};
	printf("\nInput:\n ");
	//An input array i_h (input array on host) with n elements with in the range of 0 to 256 and is a power of 2.
	for(int i = 0; i < n; i++){
		i_h[i] = pow(2,(std::rand() % 9));
		printf("%d ", i_h[i]);
	}
	int o_h[keys] = {0};
	int c_h[keys] = {0};
	int *i_d, *o_d, *c_d;
	//setup array on gpu
	cudaMalloc((void **)&i_d, sizeof(int)*n);
	cudaMalloc((void **)&o_d, sizeof(int)*n);
	cudaMalloc((void **)&c_d, sizeof(int)*keys);
	//copy values from input,etc..
	cudaMemcpy(i_d, i_h, sizeof(int)*n, cudaMemcpyHostToDevice);
	cudaMemcpy(o_d, o_d, sizeof(int)*n, cudaMemcpyHostToDevice);
	cudaMemcpy(c_d, c_h, sizeof(int)*keys, cudaMemcpyHostToDevice);

//CountSortFunction
//Get histogram
	histogram <<<6, n>>>(c_d,i_d,keys,n);
	cudaMemcpy(c_h, c_d, sizeof(int)*keys, cudaMemcpyDeviceToHost);
//Calculate Prefix sum
	naivePrefixSum<<<1,n>>>(c_d,c_d,keys);
//Fill in array
	copyToArray<<<6,n>>>(c_d,i_d,o_d,keys,n);
//Get answer
	cudaMemcpy(o_h, o_d, sizeof(int)*n, cudaMemcpyDeviceToHost);
//print answer
	printf("\nOutput:\n ");
	for (int i = 0; i < n; ++i) printf("%d ", o_h[i]);
//free memory
		cudaFree(i_d);
	cudaFree(o_d);
	cudaFree(c_d);
	
//Finish Debug Test
	printf("\nFinish debug\n");

//Performance test
	printf("Parallel function doesn't work on 2^21 and larger\n");
	printf("tried using clock but doesn't seem to work on serial function\n");
	printf("Debug test works");
	countSortSerial1();
	countSortSerial2();
	countSortSerial3();
	countSortSerial4();
	countSortSerial5();
	performanceMeasure1();
//performanceMeasure2();
//performanceMeasure3();
//performanceMeasure4();
//performanceMeasure5();
	
	return 0;
}

///////////////////////////////////////////////////////////Performance Function/////////////////////////////////////////////////////////////////
int countSortSerial1()
{   
	std::clock_t start;
	double duration;
	start = std::clock();
	const int elements = 1048576;
	const int keys = 257;

	int inputArray[elements] = {0};
	int output[elements] = {0};
	for(int i = 0; i < elements; i++)
		inputArray[i] = pow(2,(std::rand() % 9));

	int count[elements + 1] = {0};
	
    //Initalize the count array and count the number of keys
	for(int i = 0; inputArray[i]; ++i)
		++count[inputArray[i]];
	
    //calculate the starting index for each key
	int total = 0;
	int oldCount;
	for (int i = 0; i <= keys; ++i)
	{
		oldCount = count[i];
		count[i] = total;
		total += oldCount;
	}
	
    // Build the output character array
	for (int i = 0; inputArray[i]; ++i)
	{
		output[count[inputArray[i]]-1] = inputArray[i];
		--count[inputArray[i]];
	}
	
	cout << "serial counting 2^20 : " << duration << endl;
}

int countSortSerial2()
{   
	std::clock_t start;
	double duration;
	start = std::clock();
	const int elements = 1048576*2;
	const int keys = 257;

	int inputArray[elements] = {0};
	int output[elements] = {0};
	for(int i = 0; i < elements; i++)
		inputArray[i] = pow(2,(std::rand() % 9));

	int count[elements + 1] = {0};
	
    //Initalize the count array and count the number of keys
	for(int i = 0; inputArray[i]; ++i)
		++count[inputArray[i]];
	
    //calculate the starting index for each key
	int total = 0;
	int oldCount;
	for (int i = 0; i <= keys; ++i)
	{
		oldCount = count[i];
		count[i] = total;
		total += oldCount;
	}
	
    // Build the output character array
	for (int i = 0; inputArray[i]; ++i)
	{
		output[count[inputArray[i]]-1] = inputArray[i];
		--count[inputArray[i]];
	}
	
	cout << "serial counting 2^21 : " << duration << endl;
}

int countSortSerial3()
{   
	std::clock_t start;
	double duration;
	start = std::clock();
	const int elements = 1048576*2;
	const int keys = 257;

	int inputArray[elements] = {0};
	int output[elements] = {0};
	for(int i = 0; i < elements; i++)
		inputArray[i] = pow(2,(std::rand() % 9));

	int count[elements + 1] = {0};
	
    //Initalize the count array and count the number of keys
	for(int i = 0; inputArray[i]; ++i)
		++count[inputArray[i]];
	
    //calculate the starting index for each key
	int total = 0;
	int oldCount;
	for (int i = 0; i <= keys; ++i)
	{
		oldCount = count[i];
		count[i] = total;
		total += oldCount;
	}
	
    // Build the output character array
	for (int i = 0; inputArray[i]; ++i)
	{
		output[count[inputArray[i]]-1] = inputArray[i];
		--count[inputArray[i]];
	}
	
	cout << "serial counting 2^22 : " << duration << endl;
}

int countSortSerial4()
{   
	std::clock_t start;
	double duration;
	start = std::clock();
	const int elements = 1048576*2;
	const int keys = 257;

	int inputArray[elements] = {0};
	int output[elements] = {0};
	for(int i = 0; i < elements; i++)
		inputArray[i] = pow(2,(std::rand() % 9));

	int count[elements + 1] = {0};
	
    //Initalize the count array and count the number of keys
	for(int i = 0; inputArray[i]; ++i)
		++count[inputArray[i]];
	
    //calculate the starting index for each key
	int total = 0;
	int oldCount;
	for (int i = 0; i <= keys; ++i)
	{
		oldCount = count[i];
		count[i] = total;
		total += oldCount;
	}
	
    // Build the output character array
	for (int i = 0; inputArray[i]; ++i)
	{
		output[count[inputArray[i]]-1] = inputArray[i];
		--count[inputArray[i]];
	}
	
	cout << "serial counting 2^23 : " << duration << endl;
}

int countSortSerial5()
{   
	std::clock_t start;
	double duration;
	start = std::clock();
	const int elements = 1048576*2;
	const int keys = 257;

	int inputArray[elements] = {0};
	int output[elements] = {0};
	for(int i = 0; i < elements; i++)
		inputArray[i] = pow(2,(std::rand() % 9));

	int count[elements + 1] = {0};
	
    //Initalize the count array and count the number of keys
	for(int i = 0; inputArray[i]; ++i)
		++count[inputArray[i]];
	
    //calculate the starting index for each key
	int total = 0;
	int oldCount;
	for (int i = 0; i <= keys; ++i)
	{
		oldCount = count[i];
		count[i] = total;
		total += oldCount;
	}
	
    // Build the output character array
	for (int i = 0; inputArray[i]; ++i)
	{
		output[count[inputArray[i]]-1] = inputArray[i];
		--count[inputArray[i]];
	}
	
	cout << "serial counting 2^24 : " << duration << endl;
}
//Same function, but had trouble initalizing array from function parameter.
//so made copies of different performanceMeasure function 1 to 5 with different number of elements 2^20 to 2^24
int performanceMeasure1()
{
	std::clock_t start;
	double duration;
	start = std::clock();
//number of elements and number of keys
	const int elements = 1048576;
	const int keys = 257;
//setup device and host array variables
	int i_h[elements] = {0};
	for(int i = 0; i < elements; i++)
		i_h[i] = pow(2,(std::rand() % 9));
	int o_h[keys] = {0};
	int c_h[keys] = {0};
	int *i_d, *o_d, *c_d;
	//setup array on gpu
	cudaMalloc((void **)&i_d, sizeof(int)*elements);
	cudaMalloc((void **)&o_d, sizeof(int)*elements);
	cudaMalloc((void **)&c_d, sizeof(int)*keys);
	//copy values from input,etc..
	cudaMemcpy(i_d, i_h, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(o_d, o_d, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(c_d, c_h, sizeof(int)*keys, cudaMemcpyHostToDevice);
//countsort
	//Get histogram
	histogram <<<6, elements>>>(c_d,i_d,keys,elements);
	cudaMemcpy(c_h, c_d, sizeof(int)*keys, cudaMemcpyDeviceToHost);
	//Calculate Prefix sum
	naivePrefixSum<<<1,elements>>>(c_d,c_d,keys);
	//Fill in array
	copyToArray<<<6,elements>>>(c_d,i_d,o_d,keys,elements);
	//Get answer
	cudaMemcpy(o_h, o_d, sizeof(int)*elements, cudaMemcpyDeviceToHost);
	//free memory
	cudaFree(i_d);
	cudaFree(o_d);
	cudaFree(c_d);
	duration = ( std::clock() - start ) / (double) CLOCKS_PER_SEC;
	cout << "parallel counting 2^20 : " << duration << endl;
	return 0;
}


int performanceMeasure2()
{
	std::clock_t start;
	double duration;
	start = std::clock();
//number of elements and number of keys
	const int elements = 2097152;
	const int keys = 257;
//setup device and host array variables
	int i_h[elements] = {0};
	for(int i = 0; i < elements; i++)
		i_h[i] = pow(2,(std::rand() % 9));
	int o_h[keys] = {0};
	int c_h[keys] = {0};
	int *i_d, *o_d, *c_d;
	//setup array on gpu
	cudaMalloc((void **)&i_d, sizeof(int)*elements);
	cudaMalloc((void **)&o_d, sizeof(int)*elements);
	cudaMalloc((void **)&c_d, sizeof(int)*keys);
	//copy values from input,etc..
	cudaMemcpy(i_d, i_h, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(o_d, o_d, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(c_d, c_h, sizeof(int)*keys, cudaMemcpyHostToDevice);
//countsort
	//Get histogram
	histogram <<<6, elements>>>(c_d,i_d,keys,elements);
	cudaMemcpy(c_h, c_d, sizeof(int)*keys, cudaMemcpyDeviceToHost);
	//Calculate Prefix sum
	naivePrefixSum<<<1,elements>>>(c_d,c_d,keys);
	//Fill in array
	copyToArray<<<6,elements>>>(c_d,i_d,o_d,keys,elements);
	//Get answer
	cudaMemcpy(o_h, o_d, sizeof(int)*elements, cudaMemcpyDeviceToHost);
	//free memory
	cudaFree(i_d);
	cudaFree(o_d);
	cudaFree(c_d);
	cout << "parallel counting 2^21 : " << duration << endl;
	return 0;
}


int performanceMeasure3()
{
	std::clock_t start;
	double duration;
	start = std::clock();
//number of elements and number of keys
	const int elements = 4194304;
	const int keys = 257;
//setup device and host array variables
	int i_h[elements] = {0};
	for(int i = 0; i < elements; i++)
		i_h[i] = pow(2,(std::rand() % 9));
	int o_h[keys] = {0};
	int c_h[keys] = {0};
	int *i_d, *o_d, *c_d;
	//setup array on gpu
	cudaMalloc((void **)&i_d, sizeof(int)*elements);
	cudaMalloc((void **)&o_d, sizeof(int)*elements);
	cudaMalloc((void **)&c_d, sizeof(int)*keys);
	//copy values from input,etc..
	cudaMemcpy(i_d, i_h, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(o_d, o_d, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(c_d, c_h, sizeof(int)*keys, cudaMemcpyHostToDevice);
//countsort
	//Get histogram
	histogram <<<6, elements>>>(c_d,i_d,keys,elements);
	cudaMemcpy(c_h, c_d, sizeof(int)*keys, cudaMemcpyDeviceToHost);
	//Calculate Prefix sum
	naivePrefixSum<<<1,elements>>>(c_d,c_d,keys);
	//Fill in array
	copyToArray<<<6,elements>>>(c_d,i_d,o_d,keys,elements);
	//Get answer
	cudaMemcpy(o_h, o_d, sizeof(int)*elements, cudaMemcpyDeviceToHost);
	//free memory
	cudaFree(i_d);
	cudaFree(o_d);
	cudaFree(c_d);
	cout << "parallel counting 2^22 : " << duration << endl;
	return 0;
}


int performanceMeasure4()
{
	std::clock_t start;
	double duration;
	start = std::clock();
//number of elements and number of keys
	const int elements = 8388608;
	const int keys = 257;
//setup device and host array variables
	int i_h[elements] = {0};
	for(int i = 0; i < elements; i++)
		i_h[i] = pow(2,(std::rand() % 9));
	int o_h[keys] = {0};
	int c_h[keys] = {0};
	int *i_d, *o_d, *c_d;
	//setup array on gpu
	cudaMalloc((void **)&i_d, sizeof(int)*elements);
	cudaMalloc((void **)&o_d, sizeof(int)*elements);
	cudaMalloc((void **)&c_d, sizeof(int)*keys);
	//copy values from input,etc..
	cudaMemcpy(i_d, i_h, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(o_d, o_d, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(c_d, c_h, sizeof(int)*keys, cudaMemcpyHostToDevice);
//countsort
	//Get histogram
	histogram <<<6, elements>>>(c_d,i_d,keys,elements);
	cudaMemcpy(c_h, c_d, sizeof(int)*keys, cudaMemcpyDeviceToHost);
	//Calculate Prefix sum
	naivePrefixSum<<<1,elements>>>(c_d,c_d,keys);
	//Fill in array
	copyToArray<<<6,elements>>>(c_d,i_d,o_d,keys,elements);
	//Get answer
	cudaMemcpy(o_h, o_d, sizeof(int)*elements, cudaMemcpyDeviceToHost);
	//free memory
	cudaFree(i_d);
	cudaFree(o_d);
	cudaFree(c_d);
	cout << "parallel counting 2^23 : " << duration << endl;
	return 0;
}


int performanceMeasure5()
{
	std::clock_t start;
	double duration;
	start = std::clock();
//number of elements and number of keys
	const int elements = 16777216;
	const int keys = 257;
//setup device and host array variables
	int i_h[elements] = {0};
	for(int i = 0; i < elements; i++)
		i_h[i] = pow(2,(std::rand() % 9));
	int o_h[keys] = {0};
	int c_h[keys] = {0};
	int *i_d, *o_d, *c_d;
	//setup array on gpu
	cudaMalloc((void **)&i_d, sizeof(int)*elements);
	cudaMalloc((void **)&o_d, sizeof(int)*elements);
	cudaMalloc((void **)&c_d, sizeof(int)*keys);
	//copy values from input,etc..
	cudaMemcpy(i_d, i_h, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(o_d, o_d, sizeof(int)*elements, cudaMemcpyHostToDevice);
	cudaMemcpy(c_d, c_h, sizeof(int)*keys, cudaMemcpyHostToDevice);
//countsort
	//Get histogram
	histogram <<<6, elements>>>(c_d,i_d,keys,elements);
	cudaMemcpy(c_h, c_d, sizeof(int)*keys, cudaMemcpyDeviceToHost);
	//Calculate Prefix sum
	naivePrefixSum<<<1,elements>>>(c_d,c_d,keys);
	//Fill in array
	copyToArray<<<6,elements>>>(c_d,i_d,o_d,keys,elements);
	//Get answer
	cudaMemcpy(o_h, o_d, sizeof(int)*elements, cudaMemcpyDeviceToHost);
	//free memory
	cudaFree(i_d);
	cudaFree(o_d);
	cudaFree(c_d);
	cout << "parallel counting 2^24 : " << duration << endl;
	return 0;
}
