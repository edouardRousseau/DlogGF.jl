"""
# DlogGF

A library containing algorithms for computing discrete logarithm in finite
field.
"""
module DlogGF

using Nemo

# Iterator over medium subfields (of type F_q²)

function Base.start(::Nemo.FqNmodFiniteField)
    return (0,0)
end

function Base.next(F::Nemo.FqNmodFiniteField, state::Tuple{Int, Int})
    q = F.p - 1
    if state[1] < q
        nex = (state[1] + 1, state[2])
    else
        nex = (0, state[2] + 1)
    end
    return (state[1]+state[2]*gen(F), nex)
end

function Base.done(F::Nemo.FqNmodFiniteField, state::Tuple{Int, Int})
    return state[2] == F.p
end

function Base.eltype(::Type{Nemo.FqNmodFiniteField})
    return Nemo.fq_nmod
end

function Base.length(F::Nemo.FqNmodFiniteField)
    return BigInt((F.p))^(F.mod_length - 1)
end

# Random suite

export randomElem
"""
    randomElem(ring::Nemo.Ring)

Return an random element in `ring`.
"""
function randomElem(ring::Nemo.Ring)
    x = gen(ring)
    c::Int = characteristic(ring) - 1
    return ring(rand(0:c)) + rand(0:c)*x
end

export randomList
"""
    randomList(ring::Nemo.Ring, len::Integer)

Return an `Array` of length `len` with random elements in `ring`.
"""
function randomList(ring::Nemo.Ring, len::Integer)
    A = Array(ring, len)
    for i in 1:len
        A[i] = randomElem(ring)
    end
    return A
end
    
export randomPolynomial
"""
    randomPolynomial(polyRing::Nemo.PolyRing, degree::Integer)

Return a random polynomial of degree `degree` in the ring `polyRing`.
"""
function randomPolynomial(polyRing::Nemo.PolyRing, degree::Integer)
    L = randomList(base_ring(polyRing), degree + 1)
    while L[degree + 1] == 0
        L = randomList(base_ring(polyRing), degree + 1)
    end
    return polyRing(L)
end

# Composite types

export SmsrField
"""
    SmsrField

Sparse medium subfield representation of a field of the form ``\\mathbb
F_{q^{2k}}``.

This should never be called as a constructor, due to the number of the fields.
To create such a representation, see `smsrField`.

# Fields

* `h0` and `h1` are polynomials such that `h1*X^q-h0` has a degree `k`
  irreducible factor, named `definingPolynomial`
* `gen` is a generator of the inversible elements of the field
"""
immutable SmsrField
    characteristic::Integer
    extensionDegree::Integer
    cardinality::Integer
    h0::PolyElem
    h1::PolyElem
    definingPolynomial::PolyElem
    mediumSubField::Nemo.Ring
    gen::RingElem
    bigField::Nemo.Ring
end

export smsrField
"""
    smsrField(q::Integer, k::Integer, deg::Integer = 1)

Construct a field of type `SmsrField`.
"""
function smsrField(q::Integer, k::Integer, deg::Integer = 1)

    card = BigInt(q)^(2*k)
    mediumSubField, x = FiniteField(q, 2, "x")
    polyRing, T = PolynomialRing(mediumSubField, "T")
    boo = true
    h0, h1, definingPolynomial = polyRing(), polyRing(), polyRing()

    while boo
        h0 = randomPolynomial(polyRing, deg)
        h1 = randomPolynomial(polyRing, deg - 1) + T^deg
        fact = factor(h1*T^q - h0)
        for f in fact
            if degree(f[1]) == k
                definingPolynomial = f[1]
                boo = false
                break
            end
        end
    end

    bigField = ResidueRing(polyRing, definingPolynomial)
    gen = bigField(randomPolynomial(polyRing, k))

    return SmsrField(q, k, card, h0, h1, definingPolynomial,
                     mediumSubField, gen, bigField)
end

# Not sure what I should do with types in the arrays...
export FactorList
"""
    FactorsList

Represent a factorisation.
"""
type FactorsList
    factors::Array{Nemo.fq_nmod_poly, 1}
    coefs::Array{Int, 1}
    unit::Nemo.fq_nmod
end

export factorsList
"""
   factorsList(P::Nemo.fq_nmod_poly)

Construct an element of type `FactorsList`.
"""
function factorsList(P::Nemo.fq_nmod_poly)
    return FactorsList([P], [1], base_ring(parent(P))(1))
end

function Base.push!(L::FactorsList, P::Nemo.fq_nmod_poly, coef::Int)
    i = findfirst(L.factors, P)
    if i != 0
        L.coefs[i] += coef
    else
        push!(L.factors, P)
        push!(L.coefs, coef)
    end
end

function Base.deleteat!(L::FactorsList, i::Int)
    deleteat!(L.factors, i)
    deleteat!(L.coefs, i)
end

# Some functions

export pglUnperfect
function pglUnperfect(x::RingElem)
    F = parent(x)
    MS = MatrixSpace(F, 2, 2)
    M = MS()
    M[1, 1] = F(1)
    A = Array{typeof(M), 1}()
    n::Int = characteristic(F) - 1
    for a in 1:n, b in 0:n, c in 1:n
        M[1, 2] = b + a*x
        M[2, 1] = b + c*x
        M[2, 2] = a + c*x 
        push!(A, deepcopy(M))
    end
    return A
end

export homogene
function homogene{T <: PolyElem}(P::T, h0::T, h1::T)
    R = parent(P)
    q = characteristic(base_ring(R))
    H = R()
    d = degree(P)
    for i in 0:d
        H += (coeff(P, i)^q)*(h0^i)*(h1^(d-i))
    end
    return H
end

export makeEquation
function makeEquation{T <: RingElem, Y <: PolyElem}(m::Nemo.GenMat{T},
                                                    P::Y, h0::Y, h1::Y)
    a, b, c, d = m[1, 1], m[1, 2], m[2, 1], m[2, 2]
    D = degree(P)
    q = characteristic(base_ring(parent(P)))
    H = homogene(P, h0, h1)
    return ((a^q)*H + (b^q)*h1^D)*(c*P+d) - (a*P+b)*((c^q)*H + (d^q)*h1^D)
end

export isSmooth
function isSmooth(P::PolyElem, D::Int)
    d::Int = ceil(D/2)
    for f in factor(P)
        if degree(f[1]) > d
            return false
        end
    end
    return true
end

# End of module
end
