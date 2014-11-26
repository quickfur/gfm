/**
  This module implements some abstract geometric shapes:
  $(UL
  $(LI Line segments.)
  $(LI Triangle.)
  $(LI Circles/spheres.)
  $(LI Rays)
  $(LI Planes)
  $(LI Frustum)
  )
 */
module gfm.math.shapes;

import std.math,
       std.traits;

import gfm.math.vector,
       gfm.math.box;


/// A Segment is 2 points.
/// When considered like a vector, it represents the arrow from a to b.
align(1) struct Segment(T, int N)
{
    align(1):
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b;
    }
}

alias Segment!(float, 2) seg2f;  /// 2D float segment.
alias Segment!(float, 3) seg3f;  /// 3D float segment.
alias Segment!(double, 2) seg2d; /// 2D double segment.
alias Segment!(double, 3) seg3d; /// 3D double segment.

/// A Triangle is 3 points.
align(1) struct Triangle(T, int N)
{
    align(1):
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b, c;

        static if (N == 2)
        {
            /// Returns: Area of a 2D triangle.
            T area() pure const nothrow @nogc
            {
                return abs(signedArea());
            }

            /// Returns: Signed area of a 2D triangle.
            T signedArea() pure const nothrow @nogc
            {
                return ((b.x * a.y - a.x * b.y)
                      + (c.x * b.y - b.x * c.y)
                      + (a.x * c.y - c.x * a.y)) / 2;
            }
        }

        static if (N == 3)
        {
            /// Returns: Triangle normal.
            Vector!(T, 3) computeNormal() pure const nothrow @nogc
            {
                return cross(b - a, c - a).normalized();
            }
        }
    }
}

alias Triangle!(float, 2) triangle2f;  /// 2D float triangle.
alias Triangle!(float, 3) triangle3f;  /// 3D float triangle.
alias Triangle!(double, 2) triangle2d; /// 2D double triangle.
alias Triangle!(double, 3) triangle3d; /// 3D double triangle.

/// A Sphere is a point + a radius.
align(1) struct Sphere(T, int N)
{
    align(1):
    public nothrow
    {
        alias Vector!(T, N) point_t;
        point_t center;
        T radius;

        /// Creates a sphere from a point and a radius.
        this(in point_t center_, T radius_) pure nothrow @nogc
        {
            center = center_;
            radius = radius_;
        }

        /// Sphere contains point test.
        /// Returns: true if the point is inside the sphere.
        bool contains(in Sphere s) pure const nothrow @nogc
        {
            if (s.radius > radius)
                return false;

            T innerRadius = radius - s.radius;
            return squaredDistanceTo(s.center) < innerRadius * innerRadius;
        }

        /// Sphere vs point Euclidean distance squared.
        T squaredDistanceTo(point_t p) pure const nothrow @nogc
        {
            return center.squaredDistanceTo(p);
        }

        /// Sphere vs sphere intersection.
        /// Returns: true if the spheres intersect.
        bool intersects(Sphere s) pure const nothrow @nogc
        {
            T outerRadius = radius + s.radius;
            return squaredDistanceTo(s.center) < outerRadius * outerRadius;
        }

        static if (isFloatingPoint!T)
        {
            /// Sphere vs point Euclidean distance.
            T distanceTo(point_t p) pure const nothrow @nogc
            {
                return center.distanceTo(p);
            }

            static if(N == 2)
            {
                /// Returns: Circle area.
                T area() pure const nothrow @nogc
                {
                    return PI * (radius * radius);
                }
            }
        }
    }
}

alias Sphere!(float, 2) sphere2f;  /// 2D float sphere (ie. a circle).
alias Sphere!(float, 3) sphere3f;  /// 3D float sphere.
alias Sphere!(double, 2) sphere2d; /// 2D double sphere (ie. a circle).
alias Sphere!(double, 3) sphere3d; /// 3D double sphere (ie. a circle).


/// A Ray ir a point + a direction.
align(1) struct Ray(T, int N)
{
align(1):
nothrow:
    public
    {
        alias Vector!(T, N) point_t;
        point_t orig;
        point_t dir;

        /// Returns: A point further along the ray direction.
        point_t progress(T t) pure const nothrow @nogc
        {
            return orig + dir * t;
        }

        static if (N == 3)
        {
            /// Ray vs triangle intersection.
            /// See_also: "Fast, Minimum Storage Ray/Triangle intersection", Mommer & Trumbore (1997)
            /// Returns: Barycentric coordinates, the intersection point is at $(D (1 - u - v) * A + u * B + v * C).
            bool intersect(Triangle!(T, 3) triangle, out T t, out T u, out T v) pure const nothrow @nogc
            {
                point_t edge1 = triangle.b - triangle.a;
                point_t edge2 = triangle.c - triangle.a;
                point_t pvec = cross(dir, edge2);
                T det = dot(edge1, pvec);
                if (abs(det) < T.epsilon)
                    return false; // no intersection
                T invDet = 1 / det;

                // calculate distance from triangle.a to ray origin
                point_t tvec = orig - triangle.a;

                // calculate U parameter and test bounds 
                u = dot(tvec, pvec) * invDet;
                if (u < 0 || u > 1)
                    return false;

                // prepare to test V parameter
                point_t qvec = cross(tvec, edge1);

                // calculate V parameter and test bounds
                v = dot(dir, qvec) * invDet;
                if (v < 0.0 || u + v > 1.0)
                    return false;

                // calculate t, ray intersects triangle
                t = dot(edge2, qvec) * invDet;
                return true;
            }
        }
    }
}

alias Ray!(float, 2) ray2f;  /// 2D float ray.
alias Ray!(float, 3) ray3f;  /// 3D float ray.
alias Ray!(double, 2) ray2d; /// 2D double ray.
alias Ray!(double, 3) ray3d; /// 3D double ray.


/// 3D plane.
/// See_also: Flipcode article by Nate Miller $(WEB www.flipcode.com/archives/Plane_Class.shtml).
align(1) struct Plane(T) if (isFloatingPoint!T)
{
    align(1):
    public
    {
        vec3!T n; /// Normal (always stored normalized).
        T d;

        /// Create from four coordinates.
        this(vec4!T abcd) pure nothrow @nogc
        {
            n = vec3!T(abcd.x, abcd.y, abcd.z).normalized();
            d = abcd.z;
        }

        /// Create from a point and a normal.
        this(vec3!T origin, vec3!T normal) pure nothrow @nogc
        {
            n = normal.normalized();
            d = -dot(origin, n);
        }

        /// Create from 3 non-aligned points.
        this(vec3!T A, vec3!T B, vec3!T C) pure nothrow @nogc
        {
            this(C, cross(B - A, C - A));
        }

        /// Assign a plane with another plane.
        ref Plane opAssign(Plane other) pure nothrow @nogc
        {
            n = other.n;
            d = other.d;
            return this;
        }

        /// Returns: signed distance between a point and the plane.
        T signedDistanceTo(vec3!T point) pure const nothrow @nogc
        {
            return dot(n, point) + d;
        }

        /// Returns: absolute distance between a point and the plane.
        T distanceTo(vec3!T point) pure const nothrow @nogc
        {
            return abs(signedDistanceTo(point));
        }

        /// Returns: true if the point is in front of the plane.
        bool isFront(vec3!T point) pure const nothrow @nogc
        {
            return signedDistanceTo(point) >= 0;
        }

        /// Returns: true if the point is in the back of the plane.
        bool isBack(vec3!T point) pure const nothrow @nogc
        {
            return signedDistanceTo(point) < 0;
        }

        /// Returns: true if the point is on the plane, with a given epsilon.
        bool isOn(vec3!T point, T epsilon) pure const nothrow @nogc
        {
            T sd = signedDistanceTo(point);
            return (-epsilon < sd) && (sd < epsilon);
        }
    }
}

alias Plane!float planef;  /// 3D float plane.
alias Plane!double planed; /// 3D double plane.

unittest
{
    auto p = planed(vec4d(1.0, 2.0, 3.0, 4.0));
    auto p2 = planed(vec3d(1.0, 0.0, 0.0), 
                     vec3d(0.0, 1.0, 0.0), 
                     vec3d(0.0, 0.0, 1.0));

    assert(p2.isOn(vec3d(1.0, 0.0, 0.0), 1e-7));
    assert(p2.isFront(vec3d(1.0, 1.0, 1.0)));
    assert(p2.isBack(vec3d(0.0, 0.0, 0.0)));
}



/// 3D frustum.
/// See_also: Flipcode article by Dion Picco $(WEB www.flipcode.com/archives/Frustum_Culling.shtml).
/// Bugs: verify proper signedness of half-spaces
align(1) struct Frustum(T) if (isFloatingPoint!T)
{
    align(1):
    public
    {
        enum int LEFT   = 0, 
                 RIGHT  = 1,
                 TOP    = 2,
                 BOTTOM = 3,
                 NEAR   = 4,
                 FAR    = 5;

        Plane!T[6] planes;

        /// Create a frustum from 6 planes.
        this(Plane!T left, Plane!T right, Plane!T top, Plane!T bottom, Plane!T near, Plane!T far) pure nothrow @nogc
        {
            planes[LEFT] = left;
            planes[RIGHT] = right;
            planes[TOP] = top;
            planes[BOTTOM] = bottom;
            planes[NEAR] = near;
            planes[FAR] = far;
        }

        enum : int
        {
            OUTSIDE,   /// object is outside the frustum
            INTERSECT, /// object intersects with the frustum
            INSIDE     /// object is inside the frustum
        }

        /// Point vs frustum intersection.
        bool contains(vec3!T point) pure const nothrow @nogc
        {
            for(int i = 0; i < 6; ++i) 
            {
                T distance = planes[i].signedDistanceTo(point);

                if(distance < 0)
                    return false;
            }
            return true;
        }

        /// Sphere vs frustum intersection.
        /// Returns: Frustum.OUTSIDE, Frustum.INTERSECT or Frustum.INSIDE.
        int contains(Sphere!(T, 3) sphere) pure const nothrow @nogc
        {
            // calculate our distances to each of the planes
            for(int i = 0; i < 6; ++i) 
            {
                // find the distance to this plane
                T distance = planes[i].signedDistanceTo(sphere.center);

                if(distance < -sphere.radius)
                    return OUTSIDE;

                else if (distance < sphere.radius)
                    return INTERSECT;
            }

            // otherwise we are fully in view
            return INSIDE;
        }

        /// AABB vs frustum intersection.
        /// Returns: Frustum.OUTSIDE, Frustum.INTERSECT or Frustum.INSIDE.
        int contains(box3!T box) pure const nothrow @nogc
        {
            vec3!T corners[8];
            int totalIn = 0;

            for (int i = 0; i < 2; ++i)
                for (int j = 0; j < 2; ++j)
                    for (int k = 0; k < 2; ++k)
                    {
                        auto x = i == 0 ? box.min.x : box.max.x;
                        auto y = i == 0 ? box.min.y : box.max.y;
                        auto z = i == 0 ? box.min.z : box.max.z;
                        corners[i*4 + j*2 + k] = vec3!T(x, y, z);
                    }

            // test all 8 corners against the 6 sides
            // if all points are behind 1 specific plane, we are out
            // if we are in with all points, then we are fully in
            for(int p = 0; p < 6; ++p)
            {
                int inCount = 8;
                int ptIn = 1;

                for(int i = 0; i < 8; ++i)
                {
                    // test this point against the planes
                    if (planes[p].isBack(corners[i]))
                    {
                        ptIn = 0;
                        --inCount;
                    }
                }

                // were all the points outside of plane p?
                if (inCount == 0)
                    return OUTSIDE;

                // check if they were all on the right side of the plane
                totalIn += ptIn;
            }

            // so if totalIn is 6, then all are inside the view
            if(totalIn == 6)
                return INSIDE;

            // we must be partly in then otherwise
            return INTERSECT;
        }

    }
}