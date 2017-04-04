module DlogGF

using Nemo

type SmsrField
    charachteristic::Integer
    extensionDegree::Integer
    cardinality::Integer
    h0::PolyElem
    h1::PolyElem
    definingPolynomial::PolyElem
    mediumSubField::Nemo.Ring
    gen::RingElem
    BigField::Nemo.Ring
end

function randomElem(ring::Nemo.Ring)
    x = gen(ring)
    c::Int = characteristic(ring) - 1
    return ring(rand(0:c)) + rand(0:c)*x
end

function randomList(ring::Nemo.Ring, len::Integer)
    A = Array(ring, len)
    for i in 1:len
        A[i] = randomElem(ring)
    end
    return A
end
    
function randomPolynomial(polyRing::Nemo.PolyRing, degree::Integer)
    L = randomList(base_ring(polyRing), degree + 1)
    while L[degree + 1] == 0
        L = randomList(base_ring(polyRing), degree + 1)
    end
    return polyRing(L)
end

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

function makeEquation{T <: RingElem, Y <: PolyElem}(m::Nemo.GenMat{T},
                                                    P::Y, h0::Y, h1::Y)
    a, b, c, d = m[1, 1], m[1, 2], m[2, 1], m[2, 2]
    D = degree(P)
    H = homogene(P, h0, h1)
    return ((a^q)*H + (b^q)*h1^D)*(c*P+d) - (a*P+b)*((c^q)*H + (d^q)*h1^D)
end

# End of module
end
