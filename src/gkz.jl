################################################################################
#
#   gkz.jl : functions for Granger, Kleinjung, Zumbrägel algorithm
#
################################################################################

# Types for GKZ algorithm

"""
    GkzContext

Important elements in the context of the GKZ algorithm over a field ``F_{q^n}``.

# Cautions

* This should never be called as a constructor, see `gkzContext` instead.

# Fields

* `characteristic::Integer` : characteristic of the field
* `baseField::FinField` : the field ``F_q``
* `h0` and `h1` are polynomials such that ``h1*X^q - h0`` as a degree `n`
  irreducible factor, which will be the `definingPolynomial`
* `gen` is a generator of the group of invertible elements of the field, by
  default, it is taken at random *without* warranty that it is indeed a
  generator.
"""
immutable GkzContext
    characteristic::Integer
    baseField::FinField
    h0::PolyElem
    h1::PolyElem
    definingPolynomial::PolyElem
    gen::PolyElem
end

"""
    gkzContext(p::Integer, l::Integer, n::Integer, check::Bool = false)

Construct the field ``F_{q^n}`` where ``q = p^l`` in the context of the GKZ
algorithm.
"""
function gkzContext(p::Integer, l::Integer, n::Integer, check::Bool = false)

    # We create the base field ``F_q``
    z = string("z", l)
    F = FiniteField(p, l, z)[1]

    # And we find the parameters 
    h0, h1, definingPolynomial, gen = findParameters(F, n, check)

    return GkzContext(p, F, h0, h1, definingPolynomial, gen)
end

"""
    findParameters(F::FinField, n::Integer, check::Bool = false)
    
Find suitable parameters in order to perform the GKZ algorithm.
"""
function findParameters(F::FinField, n::Integer, check::Bool = false)

    # We set our polynomials
    q = length(F)
    polyRing, T = PolynomialRing(F, "T")
    h0, h1, definingPolynomial = polyRing(), polyRing(), polyRing()

    # And we search suitable polynomials h0, h1
    boo = true
    while boo
        h0 = randomElem(F)*T + randomElem(F)
        h1 = T^2 + randomElem(F)*T
        fact = factor(h1*T^q - h0)
        for f in fact
            if degree(f[1]) == n
                boo = false
                definingPolynomial = f[1]
                break
            end
        end
    end

    # Finally we find a generator
    gen = T + randomElem(F)

    if check
        while !isGenerator(gen, q^n, definingPolynomial)
            gen = T + randomElem(F)
        end
    else
        while !miniCheck(gen, q^n, definingPolynomial)
            gen = T + randomElem(F)
        end
    end

    return h0, h1, definingPolynomial, gen
end

# Ascent phase in the GKZ algorithm

"""
    ascent(Q::fq_nmod_poly)

Find an irreducible factor of degree two of `Q` in an extension.
"""
function ascent(Q::fq_nmod_poly)

    # We compute d such that deg(Q) = 2^d
    d::Int = log2(degree(Q))

    # Then we embed `Q` in degree two extensions and keep only one factor of
    # degree 2^(d-1), and we do the same with this factor, until we have a
    # factor of degree 2.

    F = base_ring(Q)
    deg = degree(F)
    c::Int = characteristic(F)
    P = Q

    for j in 1:d-1

        # We create the name of the variable of the extension
        z = string("z", deg*2^j)

        # We create the extension
        Fext = FiniteField(c, deg*2^j, z)[1]

        # We embed the polynomial in that extension
        img = findImg(Fext, F)
        F = Fext
        R, T = PolynomialRing(Fext, "T")

        # And we compute a factor
        P = anyFactor(R(P, img))
    end

    return P
end
