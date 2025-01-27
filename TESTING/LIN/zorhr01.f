*> \brief \b ZORHR01
*
*  =========== DOCUMENTATION ===========
*
* Online html documentation available at
*            http://www.netlib.org/lapack/explore-html/
*
*  Definition:
*  ===========
*
*       SUBROUTINE ZORHR01( M, N, MB1, NB1, NB2, RESULT )
*
*       .. Scalar Arguments ..
*       INTEGER           M, N, MB1, NB1, NB2
*       .. Return values ..
*       DOUBLE PRECISION  RESULT(6)
*
*
*> \par Purpose:
*  =============
*>
*> \verbatim
*>
*> ZORHR01 tests ZORHR using ZLATSQR and ZGEMQRT. Therefore, ZLATSQR
*> (used in ZGEQR) and ZGEMQRT (used in ZGEMQR) have to be tested
*> before this test.
*>
*> \endverbatim
*
*  Arguments:
*  ==========
*
*> \param[in] M
*> \verbatim
*>          M is INTEGER
*>          Number of rows in test matrix.
*> \endverbatim
*> \param[in] N
*> \verbatim
*>          N is INTEGER
*>          Number of columns in test matrix.
*> \endverbatim
*> \param[in] MB1
*> \verbatim
*>          MB1 is INTEGER
*>          Number of row in row block in an input test matrix.
*> \endverbatim
*>
*> \param[in] NB1
*> \verbatim
*>          NB1 is INTEGER
*>          Number of columns in column block an input test matrix.
*> \endverbatim
*>
*> \param[in] NB2
*> \verbatim
*>          NB2 is INTEGER
*>          Number of columns in column block in an output test matrix.
*> \endverbatim
*>
*> \param[out] RESULT
*> \verbatim
*>          RESULT is DOUBLE PRECISION array, dimension (6)
*>          Results of each of the six tests below.
*>          ( C is a M-by-N random matrix, D is a N-by-M random matrix )
*>
*>          RESULT(1) = | A - Q * R | / (eps * m * |A|)
*>          RESULT(2) = | I - (Q**H) * Q | / (eps * m )
*>          RESULT(3) = | Q * C - Q * C | / (eps * m * |C|)
*>          RESULT(4) = | (Q**H) * C - (Q**H) * C | / (eps * m * |C|)
*>          RESULT(5) = | (D * Q) - D * Q | / (eps * m * |D|)
*>          RESULT(6) = | D * (Q**H) - D * (Q**H) | / (eps * m * |D|)
*> \endverbatim
*
*  Authors:
*  ========
*
*> \author Univ. of Tennessee
*> \author Univ. of California Berkeley
*> \author Univ. of Colorado Denver
*> \author NAG Ltd.
*
*> \date June 2019
*
*> \ingroup complex16_lin
*
*  =====================================================================
      SUBROUTINE ZORHR01( M, N, MB1, NB1, NB2, RESULT )
      IMPLICIT NONE
*
*  -- LAPACK test routine (version 3.9.0) --
*  -- LAPACK is a software package provided by Univ. of Tennessee,    --
*  -- Univ. of California Berkeley, Univ. of Colorado Denver and NAG Ltd..--
*     June 2019
*
*     .. Scalar Arguments ..
      INTEGER           M, N, MB1, NB1, NB2
*     .. Return values ..
      DOUBLE PRECISION  RESULT(6)
*
*  =====================================================================
*
*     ..
*     .. Local allocatable arrays
      COMPLEX*16, ALLOCATABLE ::  A(:,:), AF(:,:), Q(:,:), R(:,:),
     $                   WORK( : ), T1(:,:), T2(:,:), DIAG(:),
     $                   C(:,:), CF(:,:), D(:,:), DF(:,:)
      DOUBLE PRECISION, ALLOCATABLE :: RWORK(:)
*
*     .. Parameters ..
      DOUBLE PRECISION   ZERO
      PARAMETER          ( ZERO = 0.0D+0 )
      COMPLEX*16         CONE, CZERO
      PARAMETER          ( CONE = ( 1.0D+0, 0.0D+0 ),
     $                     CZERO = ( 0.0D+0, 0.0D+0 ) )
*     ..
*     .. Local Scalars ..
      LOGICAL            TESTZEROS
      INTEGER            INFO, J, K, L, LWORK, NB1_UB, NB2_UB, NRB
      DOUBLE PRECISION   ANORM, EPS, RESID, CNORM, DNORM
*     ..
*     .. Local Arrays ..
      INTEGER            ISEED( 4 )
      COMPLEX*16         WORKQUERY
*     ..
*     .. External Functions ..
      DOUBLE PRECISION   DLAMCH, ZLANGE, ZLANSY
      EXTERNAL           DLAMCH, ZLANGE, ZLANSY

*     ..
*     .. Intrinsic Functions ..
      INTRINSIC          CEILING, DBLE, INT, MAX, MIN
*     ..
*     .. External Subroutines ..
      EXTERNAL           ZGEMM, ZGEMQRT, ZLACPY, ZLARNV, ZLASET,
     $                   ZLATSQR, ZORHR, ZHERK
*     ..
*     .. Scalars in Common ..
      CHARACTER(LEN=32)  SRNAMT
*     ..
*     .. Common blocks ..
      COMMON             / SRNAMC / SRNAMT
*     ..
*     .. Data statements ..
      DATA ISEED / 1988, 1989, 1990, 1991 /
*     ..
*     .. Executable Statements ..
*
*     TEST MATRICES WITH HALF OF MATRIX BEING ZEROS
*
      TESTZEROS = .FALSE.
*
      EPS = DLAMCH( 'Epsilon' )
      K = MIN( M, N )
      L = MAX( M, N, 1)
*
*     Dynamically allocate local arrays
*
      ALLOCATE ( A(M,N), AF(M,N), Q(L,L), R(M,L), RWORK(L),
     $           C(M,N), CF(M,N),
     $           D(N,M), DF(N,M) )
*
*     Put random numbers into A and copy to AF
*
      DO J = 1, N
         CALL ZLARNV( 2, ISEED, M, A( 1, J ) )
      END DO
      IF( TESTZEROS ) THEN
         IF( M.GE.4 ) THEN
            DO J = 1, N
               CALL ZLARNV( 2, ISEED, M/2, A( M/4, J ) )
            END DO
         END IF
      END IF
      CALL ZLACPY( 'Full', M, N, A, M, AF, M )
*
*     Number of row blocks in ZLATSQR
*
      NRB = MAX( 1, CEILING( DBLE( M - N ) / DBLE( MB1 - N ) ) )
*
      ALLOCATE ( T1( NB1, N * NRB ) )
      ALLOCATE ( T2( NB2, N ) )
      ALLOCATE ( DIAG( N ) )
*
*     Determine LWORK for the array WORK
*
*     ZLATSQR requires NB1 to be bounded by N.
*
      NB1_UB = MIN( NB1, N)
*
*     ZGEMQRT requires NB2 to be bounded by N.
*
      NB2_UB = MIN( NB2, N)
*
      CALL ZLATSQR( M, N, MB1, NB1_UB, AF, M, T1, NB1,
     $              WORKQUERY, -1, INFO )
      LWORK = INT( WORKQUERY )
      CALL ZORHR( M, N, MB1, NB1, AF, M, T1, NB1, NB2, T2, NB2, DIAG,
     $            WORKQUERY, -1, INFO)
      LWORK = MAX( LWORK, INT( WORKQUERY ) )
*
*     In ZGEMQRT, WORK is N*NB2_UB if SIDE = 'L',
*                or  M*NB2_UB if SIDE = 'R'.
*
      LWORK = MAX( LWORK, NB2_UB * N, NB2_UB * M )
*
      ALLOCATE ( WORK( LWORK ) )
*
*     Factor the matrix A in the array AF.
*
      SRNAMT = 'ZLATSQR'
      CALL ZLATSQR( M, N, MB1, NB1_UB, AF, M, T1, NB1, WORK, LWORK,
     $              INFO )
*
      SRNAMT = 'ZORHR'
      CALL ZORHR( M, N, MB1, NB1, AF, M, T1, NB1, NB2, T2, NB2, DIAG,
     $            WORK, LWORK, INFO )
*
*     Generate the m-by-m matrix Q
*
      CALL ZLASET( 'Full', M, M, CZERO, CONE, Q, M )
*
      SRNAMT = 'ZGEMQRT'
      CALL ZGEMQRT( 'L', 'N', M, M, K, NB2_UB, AF, M, T2, NB2, Q, M,
     $              WORK, INFO )
*
*     Copy R
*
      CALL ZLASET( 'Full', M, N, CZERO, CZERO, R, M )
*
      CALL ZLACPY( 'Upper', M, N, AF, M, R, M )
*
*     TEST 1
*     Compute |R - (Q**H)*A| / ( eps * m * |A| ) and store in RESULT(1)
*
      CALL ZGEMM( 'C', 'N', M, N, M, -CONE, Q, M, A, M, CONE, R, M )
*
      ANORM = ZLANGE( '1', M, N, A, M, RWORK )
      RESID = ZLANGE( '1', M, N, R, M, RWORK )
      IF( ANORM.GT.ZERO ) THEN
         RESULT( 1 ) = RESID / ( EPS * MAX( 1, M ) * ANORM )
      ELSE
         RESULT( 1 ) = ZERO
      END IF
*
*     TEST 2
*     Compute |I - (Q**H)*Q| / ( eps * m ) and store in RESULT(2)
*
      CALL ZLASET( 'Full', M, M, CZERO, CONE, R, M )
      CALL ZHERK( 'U', 'C', M, M, -CONE, Q, M, CONE, R, M )
      RESID = ZLANSY( '1', 'Upper', M, R, M, RWORK )
      RESULT( 2 ) = RESID / ( EPS * MAX( 1, M ) )
*
*     Generate random m-by-n matrix C
*
      DO J = 1, N
         CALL ZLARNV( 2, ISEED, M, C( 1, J ) )
      END DO
      CNORM = ZLANGE( '1', M, N, C, M, RWORK )
      CALL ZLACPY( 'Full', M, N, C, M, CF, M )
*
*     Apply Q to C as Q*C = CF
*
      SRNAMT = 'ZGEMQRT'
      CALL ZGEMQRT( 'L', 'N', M, N, K, NB2_UB, AF, M, T2, NB2, CF, M,
     $               WORK, INFO )
*
*     TEST 3
*     Compute |CF - Q*C| / ( eps *  m * |C| )
*
      CALL ZGEMM( 'N', 'N', M, N, M, -CONE, Q, M, C, M, CONE, CF, M )
      RESID = ZLANGE( '1', M, N, CF, M, RWORK )
      IF( CNORM.GT.ZERO ) THEN
         RESULT( 3 ) = RESID / ( EPS * MAX( 1, M ) * CNORM )
      ELSE
         RESULT( 3 ) = ZERO
      END IF
*
*     Copy C into CF again
*
      CALL ZLACPY( 'Full', M, N, C, M, CF, M )
*
*     Apply Q to C as (Q**H)*C = CF
*
      SRNAMT = 'ZGEMQRT'
      CALL ZGEMQRT( 'L', 'C', M, N, K, NB2_UB, AF, M, T2, NB2, CF, M,
     $               WORK, INFO )
*
*     TEST 4
*     Compute |CF - (Q**H)*C| / ( eps * m * |C|)
*
      CALL ZGEMM( 'C', 'N', M, N, M, -CONE, Q, M, C, M, CONE, CF, M )
      RESID = ZLANGE( '1', M, N, CF, M, RWORK )
      IF( CNORM.GT.ZERO ) THEN
         RESULT( 4 ) = RESID / ( EPS * MAX( 1, M ) * CNORM )
      ELSE
         RESULT( 4 ) = ZERO
      END IF
*
*     Generate random n-by-m matrix D and a copy DF
*
      DO J = 1, M
         CALL ZLARNV( 2, ISEED, N, D( 1, J ) )
      END DO
      DNORM = ZLANGE( '1', N, M, D, N, RWORK )
      CALL ZLACPY( 'Full', N, M, D, N, DF, N )
*
*     Apply Q to D as D*Q = DF
*
      SRNAMT = 'ZGEMQRT'
      CALL ZGEMQRT( 'R', 'N', N, M, K, NB2_UB, AF, M, T2, NB2, DF, N,
     $               WORK, INFO )
*
*     TEST 5
*     Compute |DF - D*Q| / ( eps * m * |D| )
*
      CALL ZGEMM( 'N', 'N', N, M, M, -CONE, D, N, Q, M, CONE, DF, N )
      RESID = ZLANGE( '1', N, M, DF, N, RWORK )
      IF( DNORM.GT.ZERO ) THEN
         RESULT( 5 ) = RESID / ( EPS * MAX( 1, M ) * DNORM )
      ELSE
         RESULT( 5 ) = ZERO
      END IF
*
*     Copy D into DF again
*
      CALL ZLACPY( 'Full', N, M, D, N, DF, N )
*
*     Apply Q to D as D*(Q**H) = DF
*
      SRNAMT = 'ZGEMQRT'
      CALL ZGEMQRT( 'R', 'C', N, M, K, NB2_UB, AF, M, T2, NB2, DF, N,
     $               WORK, INFO )
*
*     TEST 6
*     Compute |DF - D*(Q**H)| / ( eps * m * |D| )
*
      CALL ZGEMM( 'N', 'C', N, M, M, -CONE, D, N, Q, M, CONE, DF, N )
      RESID = ZLANGE( '1', N, M, DF, N, RWORK )
      IF( DNORM.GT.ZERO ) THEN
         RESULT( 6 ) = RESID / ( EPS * MAX( 1, M ) * DNORM )
      ELSE
         RESULT( 6 ) = ZERO
      END IF
*
*     Deallocate all arrays
*
      DEALLOCATE ( A, AF, Q, R, RWORK, WORK, T1, T2, DIAG,
     $             C, D, CF, DF )
*
      RETURN
*
*     End of ZORHR01
*
      END
