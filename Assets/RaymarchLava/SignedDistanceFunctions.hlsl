///
// Operators
///
float Combine( float d1, float d2 ) { return min(d1,d2); }

float Subtract( float d1, float d2 ) { return max(-d1,d2); }

float Intersect( float d1, float d2 ) { return max(d1,d2); }

///
// Smooth Operators // https://youtu.be/4TYv2PhG89A
///
float SmoothCombine( float d1, float d2, float k ) {
    float h = max(k-abs(d1-d2),0.0);
    return min(d1, d2) - h*h*0.25/k;
}

float SmoothSubtract( float d1, float d2, float k ) {
    float h = max(k-abs(-d1-d2),0.0);
    return max(-d1, d2) + h*h*0.25/k;
}

float SmoothIntersect( float d1, float d2, float k ) {
    float h = max(k-abs(d1-d2),0.0);
    return max(d1, d2) + h*h*0.25/k;
}