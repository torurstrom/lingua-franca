/**
 * generated by Xtext 2.17.0
 */
package org.icyphy.linguaFranca;

import org.eclipse.emf.common.util.EList;

import org.eclipse.emf.ecore.EObject;

/**
 * <!-- begin-user-doc -->
 * A representation of the model object '<em><b>Assignments</b></em>'.
 * <!-- end-user-doc -->
 *
 * <p>
 * The following features are supported:
 * </p>
 * <ul>
 *   <li>{@link org.icyphy.linguaFranca.Assignments#getAssignments <em>Assignments</em>}</li>
 * </ul>
 *
 * @see org.icyphy.linguaFranca.LinguaFrancaPackage#getAssignments()
 * @model
 * @generated
 */
public interface Assignments extends EObject
{
  /**
   * Returns the value of the '<em><b>Assignments</b></em>' containment reference list.
   * The list contents are of type {@link org.icyphy.linguaFranca.Assignment}.
   * <!-- begin-user-doc -->
   * <p>
   * If the meaning of the '<em>Assignments</em>' containment reference list isn't clear,
   * there really should be more of a description here...
   * </p>
   * <!-- end-user-doc -->
   * @return the value of the '<em>Assignments</em>' containment reference list.
   * @see org.icyphy.linguaFranca.LinguaFrancaPackage#getAssignments_Assignments()
   * @model containment="true"
   * @generated
   */
  EList<Assignment> getAssignments();

} // Assignments
